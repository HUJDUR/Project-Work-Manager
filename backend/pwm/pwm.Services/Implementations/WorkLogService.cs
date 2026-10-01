using FluentValidation;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using pwm.Common.Services.Time;
using pwm.Model.Access;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Business;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class WorkLogService
        : BaseCRUDService<WorkLog, WorkLogResponse, WorkLogSearchObject, WorkLogInsertRequest, WorkLogUpdateRequest>, IWorkLogService
    {
        private readonly ICurrentUser _currentUser;

        public WorkLogService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<WorkLogInsertRequest> insertValidator,
            IValidator<WorkLogUpdateRequest> updateValidator,
            ICurrentUser currentUser)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _currentUser = currentUser;
        }

        /// <summary>
        /// The Clock In screen: the session running now, the projects in production,
        /// and the operations this account is qualified for - who is asking comes
        /// from the token.
        /// </summary>
        public async Task<ClockInOptionsResponse> GetClockInOptionsAsync()
        {
            var userId = CurrentUserIdOrThrow();

            return new ClockInOptionsResponse
            {
                Session = await DescribeAsync(_dbContext.WorkLogDetails
                    .Where(x => x.UserId == userId && x.FinishedAt == null)),
                Projects = await _dbContext.Projects
                    .Where(x => x.ProjectStatus.Name == ProjectStatusRules.InProduction)
                    .OrderBy(x => x.Code)
                    .Select(x => new ClockInOptionResponse
                    {
                        Id = x.Id,
                        Name = x.Code == "" ? x.Name : x.Code + " - " + x.Name,
                    })
                    .ToListAsync(),
                Operations = await _dbContext.UserOperations
                    .Where(x => x.UserId == userId)
                    .OrderBy(x => x.OperationType.Name)
                    .Select(x => new ClockInOptionResponse { Id = x.OperationTypeId, Name = x.OperationType.Name })
                    .ToListAsync(),
            };
        }

        /// <summary>
        /// Starts a session now, on today's shift - raising the shift if this is the
        /// day's first session, reopening it if the day was already clocked out of.
        /// The time is the server's, never the phone's, and the whole thing is one
        /// save: shift and session together, or neither.
        /// </summary>
        public async Task<ClockSessionResponse> ClockInAsync(ClockInRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);

            var userId = CurrentUserIdOrThrow();
            var now = DateTime.UtcNow;

            await WorkBookingRules.EnsureProjectAllowsBookingAsync(_dbContext, request.ProjectId, request.OperationTypeId);
            await WorkBookingRules.EnsureQualifiedAsync(_dbContext, userId, request.OperationTypeId);
            WorkBookingRules.EnsureNoteFits(request.Note);
            // Also what refuses a second clock-in while a session is still running.
            await WorkBookingRules.EnsureNoOverlapAsync(_dbContext, userId, now, end: null, exceptBlockId: null);

            var dayStart = SarajevoTime.StartOfDayUtc(SarajevoTime.Today);
            var dayEnd = SarajevoTime.StartOfDayUtc(SarajevoTime.Today.AddDays(1));

            var shift = await _dbContext.WorkLogs
                .Where(x => x.UserId == userId && x.ClockedIn >= dayStart && x.ClockedIn < dayEnd)
                .OrderBy(x => x.ClockedIn)
                .FirstOrDefaultAsync();

            if (shift is null)
            {
                shift = new WorkLog { UserId = userId, ClockedIn = now, Hours = 0 };
                _dbContext.WorkLogs.Add(shift);
            }
            else
            {
                // Back on the clock: the day is not over after all.
                shift.ClockedOut = null;
            }

            var session = new WorkLogDetail
            {
                WorkLog = shift,
                UserId = userId,
                ProjectId = request.ProjectId,
                OperationTypeId = request.OperationTypeId,
                StartedAt = now,
                Hours = 0,
                Note = WorkBookingRules.CleanNote(request.Note),
            };
            _dbContext.WorkLogDetails.Add(session);

            await MonthlyHourSummary.SaveAndRecalculateAsync(_dbContext, [now]);

            return (await DescribeAsync(_dbContext.WorkLogDetails.Where(x => x.Id == session.Id)))!;
        }

        /// <summary>
        /// Ends the running session now, and totals the day back onto its shift. The
        /// hours are worked out here from the two times. A session left running for
        /// more than a day is not closed - that is somebody who forgot, and the
        /// office corrects it rather than a phone booking a day and a half.
        /// </summary>
        public async Task<ClockSessionResponse> ClockOutAsync()
        {
            var userId = CurrentUserIdOrThrow();
            var now = DateTime.UtcNow;

            var session = await _dbContext.WorkLogDetails
                    .Include(x => x.WorkLog)
                    .Where(x => x.UserId == userId && x.FinishedAt == null)
                    .OrderByDescending(x => x.StartedAt)
                    .FirstOrDefaultAsync()
                ?? throw new ClientException("You are not clocked in.");

            var hours = WorkBookingRules.HoursBetween(session.StartedAt, now);
            if (hours > WorkBookingRules.MaxHours)
            {
                throw new ClientException(
                    $"This session has been running for more than {WorkBookingRules.MaxHours} hours - " +
                    "ask the office to correct it.");
            }

            session.FinishedAt = now;
            session.Hours = hours;

            var shift = session.WorkLog;
            var otherHours = await _dbContext.WorkLogDetails
                .Where(x => x.WorkLogId == shift.Id && x.Id != session.Id)
                .SumAsync(x => x.Hours);

            shift.ClockedOut = now;
            shift.Hours = Math.Round(otherHours + hours, 2);

            await MonthlyHourSummary.SaveAndRecalculateAsync(_dbContext, [session.StartedAt]);

            return (await DescribeAsync(_dbContext.WorkLogDetails.Where(x => x.Id == session.Id)))!;
        }

        /// <summary>
        /// A whole shift, with every block on it (the database cascades them) - and
        /// the months those blocks were in recalculated in the same transaction.
        /// </summary>
        public override async Task DeleteAsync(int id)
        {
            var shift = await _dbContext.WorkLogs.FindAsync(id)
                ?? throw new NotFoundException($"WorkLog with id {id} not found.");

            var touched = await _dbContext.WorkLogDetails
                .Where(x => x.WorkLogId == id)
                .Select(x => x.StartedAt)
                .ToListAsync();

            _dbContext.WorkLogs.Remove(shift);

            await MonthlyHourSummary.SaveAndRecalculateAsync(_dbContext, touched);
        }

        private Task<ClockSessionResponse?> DescribeAsync(IQueryable<WorkLogDetail> query) => query
            .OrderByDescending(x => x.StartedAt)
            .Select(x => new ClockSessionResponse
            {
                WorkLogDetailId = x.Id,
                WorkLogId = x.WorkLogId,
                ProjectId = x.ProjectId,
                ProjectLabel = x.Project.Code == "" ? x.Project.Name : x.Project.Code + " - " + x.Project.Name,
                OperationTypeId = x.OperationTypeId,
                OperationName = x.OperationType.Name,
                StartedAt = x.StartedAt,
                FinishedAt = x.FinishedAt,
                Hours = x.Hours,
                Note = x.Note,
            })
            .FirstOrDefaultAsync();

        /// <summary>A worker only ever sees their own shifts; the office anyone's.</summary>
        public override async Task<WorkLogResponse> GetByIdAsync(int id)
        {
            var shift = await base.GetByIdAsync(id);

            if (_currentUser.IsWorker && shift.UserId != _currentUser.Id)
            {
                throw new NotFoundException($"WorkLog with id {id} not found.");
            }

            return shift;
        }

        protected override IQueryable<WorkLog> ApplyFilters(IQueryable<WorkLog> query, WorkLogSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            // "Mine" and a worker's every read are the token's account, never an id
            // the client sent; the office may still look at a chosen worker.
            var userId = _currentUser.IsWorker || search.Mine == true ? CurrentUserIdOrThrow() : search.UserId;
            if (userId.HasValue)
            {
                query = query.Where(x => x.UserId == userId.Value);
            }

            if (search.DateFrom.HasValue)
            {
                query = query.Where(x => x.ClockedIn >= search.DateFrom.Value);
            }

            if (search.DateTo.HasValue)
            {
                query = query.Where(x => x.ClockedIn <= search.DateTo.Value);
            }

            return query;
        }

        private int CurrentUserIdOrThrow() =>
            _currentUser.Id ?? throw new ForbiddenException("The token carries no user.");
    }
}
