using FluentValidation;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using pwm.Model.Access;
using pwm.Model.Enums;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Business;
using pwm.Services.Database;
using pwm.Services.Interfaces;
using pwm.Common.Services.Time;
using pwm.Services.Reporting;

namespace pwm.Services.Implementations
{
    public class WorkLogDetailService
        : BaseCRUDService<WorkLogDetail, WorkLogDetailResponse, WorkLogDetailSearchObject, WorkLogDetailInsertRequest, WorkLogDetailUpdateRequest>, IWorkLogDetailService
    {
        private readonly ICurrentUser _currentUser;

        public WorkLogDetailService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<WorkLogDetailInsertRequest> insertValidator,
            IValidator<WorkLogDetailUpdateRequest> updateValidator,
            ICurrentUser currentUser)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _currentUser = currentUser;
        }

        // A block has no user of its own; ownership is the shift it belongs to.
        public override async Task<WorkLogDetailResponse> InsertAsync(WorkLogDetailInsertRequest request)
        {
            await EnsureOwnShiftAsync(request.WorkLogId);
            await EnsureProjectAllowsBookingAsync(request.ProjectId, request.OperationTypeId);

            return await base.InsertAsync(request);
        }

        public override async Task<WorkLogDetailResponse> UpdateAsync(int id, WorkLogDetailUpdateRequest request)
        {
            // Both the block being changed and the shift it is being moved onto.
            await EnsureOwnBlockAsync(id);
            await EnsureOwnShiftAsync(request.WorkLogId);
            await EnsureProjectAllowsBookingAsync(request.ProjectId, request.OperationTypeId);

            return await base.UpdateAsync(id, request);
        }

        /// <summary>
        /// A project not actively worked (On hold, Delivered, Rejected) takes no
        /// new hours at all; one still only being quoted (Potential) takes only
        /// office hours - the shop floor has not been told to start yet. See
        /// <see cref="ProjectStatusRules"/>.
        /// </summary>
        private async Task EnsureProjectAllowsBookingAsync(int projectId, int operationTypeId)
        {
            var project = await _dbContext.Projects
                    .Include(x => x.ProjectStatus)
                    .FirstOrDefaultAsync(x => x.Id == projectId)
                ?? throw new NotFoundException($"Project with id {projectId} not found.");

            if (!ProjectStatusRules.CanBookAnything(project.ProjectStatus.Name))
            {
                throw new ClientException(
                    $"A \"{project.ProjectStatus.Name}\" project cannot have new hours booked against it.");
            }

            if (!ProjectStatusRules.RequiresOfficeOperationOnly(project.ProjectStatus.Name))
            {
                return;
            }

            var operationName = await _dbContext.OperationTypes
                    .Where(x => x.Id == operationTypeId)
                    .Select(x => x.Name)
                    .FirstOrDefaultAsync()
                ?? throw new NotFoundException($"OperationType with id {operationTypeId} not found.");

            if (!ProjectStatusRules.IsOfficeOperation(operationName))
            {
                throw new ClientException(
                    "A project still being quoted only takes office hours - Office work or Technical preparation.");
            }
        }

        /// <summary>
        /// Removes the block, and the shift with it when nothing else was booked
        /// against it - a shift with no work on it is not a record of anything.
        /// Both go in one save.
        /// </summary>
        public override async Task DeleteAsync(int id)
        {
            await EnsureOwnBlockAsync(id);

            var block = await _dbContext.WorkLogDetails.FindAsync(id)
                ?? throw new NotFoundException($"WorkLogDetail with id {id} not found.");

            var hasSiblings = await _dbContext.WorkLogDetails
                .AnyAsync(x => x.WorkLogId == block.WorkLogId && x.Id != id);

            _dbContext.WorkLogDetails.Remove(block);

            if (!hasSiblings)
            {
                var shift = await _dbContext.WorkLogs.FindAsync(block.WorkLogId);
                if (shift is not null)
                {
                    _dbContext.WorkLogs.Remove(shift);
                }
            }

            await _dbContext.SaveChangesAsync();
        }

        private async Task EnsureOwnBlockAsync(int id)
        {
            if (!_currentUser.IsWorker)
            {
                return;
            }

            var existing = await GetByIdAsync(id);

            await EnsureOwnShiftAsync(existing.WorkLogId);
        }

        private async Task EnsureOwnShiftAsync(int workLogId)
        {
            if (!_currentUser.IsWorker)
            {
                return;
            }

            var shift = await _dbContext.WorkLogs.FindAsync(workLogId)
                ?? throw new NotFoundException($"WorkLog with id {workLogId} not found.");

            if (shift.UserId != _currentUser.Id)
            {
                throw new ForbiddenException("You can only book hours against your own shift.");
            }
        }

        public async Task<PageResult<WorkHoursEntryResponse>> GetHoursAsync(WorkHoursSearchObject search)
        {
            ClampPaging(search);

            var query = _dbContext.WorkLogDetails.AsQueryable();

            if (!string.IsNullOrWhiteSpace(search.Search))
            {
                var needle = search.Search.Trim();
                query = query.Where(x => EF.Functions.Like(x.User.Name + " " + x.User.Surname, $"%{needle}%"));
            }

            if (search.ProjectId.HasValue)
            {
                query = query.Where(x => x.ProjectId == search.ProjectId.Value);
            }

            // Whole Sarajevo days, whatever time of day the client's values carry.
            if (search.DateFrom.HasValue)
            {
                var from = SarajevoTime.StartOfDayUtc(SarajevoTime.DayOf(search.DateFrom.Value));
                query = query.Where(x => x.StartedAt >= from);
            }

            if (search.DateTo.HasValue)
            {
                var toExclusive = SarajevoTime.StartOfDayUtc(SarajevoTime.DayOf(search.DateTo.Value).AddDays(1));
                query = query.Where(x => x.StartedAt < toExclusive);
            }

            if (search.HoursFilter == WorkHoursFilter.InProgressOnly)
            {
                query = query.Where(x => x.FinishedAt == null || x.WorkLog.ClockedOut == null);
            }

            var rows = await query
                .Select(x => new
                {
                    x.Id,
                    x.WorkLogId,
                    x.UserId,
                    x.ProjectId,
                    x.OperationTypeId,
                    x.User.Name,
                    x.User.Surname,
                    ProjectName = x.Project.Name,
                    OperationName = x.OperationType.Name,
                    x.StartedAt,
                    x.FinishedAt,
                    x.Hours,
                    InProgress = x.FinishedAt == null || x.WorkLog.ClockedOut == null,
                })
                .ToListAsync();

            var regularById = await RegularHoursAsync(rows.Select(x => (x.UserId, x.StartedAt)).ToList());

            var entries = rows
                .Select(x =>
                {
                    var regular = regularById[x.Id];
                    return new WorkHoursEntryResponse
                    {
                        Id = x.Id,
                        WorkLogId = x.WorkLogId,
                        UserId = x.UserId,
                        ProjectId = x.ProjectId,
                        OperationTypeId = x.OperationTypeId,
                        WorkerName = $"{x.Name} {x.Surname}".Trim(),
                        WorkerInitials = Initials(x.Name, x.Surname),
                        ProjectName = x.ProjectName,
                        OperationName = x.OperationName,
                        StartedAt = x.StartedAt,
                        FinishedAt = x.FinishedAt,
                        RegularHours = regular,
                        OvertimeHours = x.Hours - regular,
                        InProgress = x.InProgress,
                    };
                })
                .Where(x => search.HoursFilter switch
                {
                    WorkHoursFilter.RegularOnly => x.OvertimeHours <= 0,
                    WorkHoursFilter.OvertimeOnly => x.OvertimeHours > 0,
                    _ => true,
                })
                .OrderByDescending(x => x.StartedAt)
                .ThenByDescending(x => x.Id)
                .ToList();

            return new PageResult<WorkHoursEntryResponse>
            {
                Items = entries
                    .Skip((search.Page!.Value - 1) * search.PageSize!.Value)
                    .Take(search.PageSize.Value)
                    .ToList(),
                TotalCount = search.IncludeTotalCount == true ? entries.Count : null,
            };
        }

        /// <summary>
        /// The regular part of each block, by block id. Overtime is whatever a worker
        /// books past <see cref="ReportBuilder.RegularHoursPerDay"/> on one Sarajevo
        /// day, in start order - so
        /// it depends on every block of that worker's day, not only the ones the
        /// filters matched. Those are read in one query covering the matched days.
        /// </summary>
        private async Task<Dictionary<int, double>> RegularHoursAsync(List<(int UserId, DateTime StartedAt)> matched)
        {
            if (matched.Count == 0)
            {
                return [];
            }

            var userIds = matched.Select(x => x.UserId).Distinct().ToList();
            var firstDay = SarajevoTime.StartOfDayUtc(SarajevoTime.DayOf(matched.Min(x => x.StartedAt)));
            var afterLastDay = SarajevoTime.StartOfDayUtc(SarajevoTime.DayOf(matched.Max(x => x.StartedAt)).AddDays(1));

            var dayBlocks = await _dbContext.WorkLogDetails
                .Where(x => userIds.Contains(x.UserId) && x.StartedAt >= firstDay && x.StartedAt < afterLastDay)
                .Select(x => new { x.Id, x.UserId, x.StartedAt, x.Hours })
                .ToListAsync();

            var regularById = new Dictionary<int, double>();

            foreach (var day in dayBlocks.GroupBy(x => (x.UserId, SarajevoTime.DayOf(x.StartedAt))))
            {
                var used = 0.0;

                foreach (var block in day.OrderBy(x => x.StartedAt).ThenBy(x => x.Id))
                {
                    regularById[block.Id] = Math.Clamp(ReportBuilder.RegularHoursPerDay - used, 0, block.Hours);
                    used += block.Hours;
                }
            }

            return regularById;
        }

        private static string Initials(string name, string surname)
        {
            var initials = string.Concat(name.Take(1).Concat(surname.Take(1))).ToUpperInvariant();
            return initials.Length == 0 ? "?" : initials;
        }

        protected override IQueryable<WorkLogDetail> ApplyFilters(IQueryable<WorkLogDetail> query, WorkLogDetailSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.WorkLogId.HasValue)
            {
                query = query.Where(x => x.WorkLogId == search.WorkLogId.Value);
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (search.ProjectId.HasValue)
            {
                query = query.Where(x => x.ProjectId == search.ProjectId.Value);
            }

            if (search.OperationTypeId.HasValue)
            {
                query = query.Where(x => x.OperationTypeId == search.OperationTypeId.Value);
            }

            if (search.DateFrom.HasValue)
            {
                query = query.Where(x => x.StartedAt >= search.DateFrom.Value);
            }

            if (search.DateTo.HasValue)
            {
                query = query.Where(x => x.StartedAt <= search.DateTo.Value);
            }

            return query;
        }
    }
}
