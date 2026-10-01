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

namespace pwm.Services.Implementations
{
    public class WorkLogDetailService
        : BaseCRUDService<WorkLogDetail, WorkLogDetailResponse, WorkLogDetailSearchObject, WorkLogDetailInsertRequest, WorkLogDetailUpdateRequest>, IWorkLogDetailService
    {
        private readonly ICurrentUser _currentUser;
        private readonly INotificationService _notifications;

        public WorkLogDetailService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<WorkLogDetailInsertRequest> insertValidator,
            IValidator<WorkLogDetailUpdateRequest> updateValidator,
            ICurrentUser currentUser,
            INotificationService notifications)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _currentUser = currentUser;
            _notifications = notifications;
        }

        /// <summary>
        /// A block of work booked by the office (a worker clocks in through
        /// <c>WorkLogService.ClockInAsync</c> instead). The request's user and hours
        /// are not trusted: the user is the shift's, the hours are worked out from
        /// the two times, and the shift's total is brought up to date in the same save.
        /// </summary>
        public override async Task<WorkLogDetailResponse> InsertAsync(WorkLogDetailInsertRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);
            await _insertValidator.ValidateAndThrowAsync(request);

            var shift = await FindShiftAsync(request.WorkLogId);
            await EnsureBookableAsync(shift.UserId, request, exceptBlockId: null);

            var block = _mapper.Map<WorkLogDetail>(request);
            block.Note = WorkBookingRules.CleanNote(request.Note);
            block.UserId = shift.UserId;
            block.Hours = HoursOf(request);
            _dbContext.WorkLogDetails.Add(block);

            RetotalShift(shift, await SavedHoursAsync(shift.Id, exceptBlockId: null) + block.Hours);
            await RecordChangeAsync(block, shift.UserId, WorkHoursChangeAction.Added, before: null, after: await DescribeAsync(block));
            await MonthlyHourSummary.SaveAndRecalculateAsync(_dbContext, [block.StartedAt]);

            return _mapper.Map<WorkLogDetailResponse>(block);
        }

        public override async Task<WorkLogDetailResponse> UpdateAsync(int id, WorkLogDetailUpdateRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);
            await _updateValidator.ValidateAndThrowAsync(request);

            var block = await _dbContext.WorkLogDetails.FindAsync(id)
                ?? throw new NotFoundException($"WorkLogDetail with id {id} not found.");
            var previousShiftId = block.WorkLogId;
            var previousStart = block.StartedAt;
            var before = await DescribeAsync(block);

            var shift = await FindShiftAsync(request.WorkLogId);
            await EnsureBookableAsync(shift.UserId, request, exceptBlockId: id);

            _mapper.Map(request, block);
            block.Note = WorkBookingRules.CleanNote(request.Note);
            block.UserId = shift.UserId;
            block.Hours = HoursOf(request);

            RetotalShift(shift, await SavedHoursAsync(shift.Id, exceptBlockId: id) + block.Hours);
            if (previousShiftId != shift.Id)
            {
                // Moved off another shift - that one's total drops by it.
                RetotalShift(await FindShiftAsync(previousShiftId), await SavedHoursAsync(previousShiftId, exceptBlockId: id));
            }

            var after = await DescribeAsync(block);
            if (after != before)
            {
                await RecordChangeAsync(block, shift.UserId, WorkHoursChangeAction.Changed, before, after);
            }

            await MonthlyHourSummary.SaveAndRecalculateAsync(_dbContext, [previousStart, block.StartedAt]);

            return _mapper.Map<WorkLogDetailResponse>(block);
        }

        /// <summary>
        /// Removes the block, and the shift with it when nothing else was booked
        /// against it - a shift with no work on it is not a record of anything.
        /// Otherwise the shift's total drops by it. One save either way.
        /// </summary>
        public override async Task DeleteAsync(int id)
        {
            var block = await _dbContext.WorkLogDetails.FindAsync(id)
                ?? throw new NotFoundException($"WorkLogDetail with id {id} not found.");

            var hasSiblings = await _dbContext.WorkLogDetails
                .AnyAsync(x => x.WorkLogId == block.WorkLogId && x.Id != id);

            // Recorded without the block itself - it is gone after this save, and
            // this row is the part of its story that has to stay.
            await RecordChangeAsync(block: null, block.UserId, WorkHoursChangeAction.Deleted,
                before: await DescribeAsync(block), after: null);

            _dbContext.WorkLogDetails.Remove(block);

            var shift = await _dbContext.WorkLogs.FindAsync(block.WorkLogId);
            if (shift is not null)
            {
                if (hasSiblings)
                {
                    RetotalShift(shift, await SavedHoursAsync(shift.Id, exceptBlockId: id));
                }
                else
                {
                    _dbContext.WorkLogs.Remove(shift);
                }
            }

            await MonthlyHourSummary.SaveAndRecalculateAsync(_dbContext, [block.StartedAt]);
        }

        /// <summary>A worker only ever sees their own blocks; the office anyone's.</summary>
        public override async Task<WorkLogDetailResponse> GetByIdAsync(int id)
        {
            var block = await base.GetByIdAsync(id);

            if (_currentUser.IsWorker && block.UserId != _currentUser.Id)
            {
                throw new NotFoundException($"WorkLogDetail with id {id} not found.");
            }

            return block;
        }

        /// <summary>
        /// The trail behind one block - who changed it, when, and from what to what -
        /// newest first. Its deletion is not reachable here, since the block is gone;
        /// the admins and project managers were told of it when it happened.
        /// </summary>
        public async Task<List<WorkHoursChangeResponse>> GetHistoryAsync(int workLogDetailId) =>
            await _dbContext.WorkHoursChanges
                .Where(x => x.WorkLogDetailId == workLogDetailId)
                .OrderByDescending(x => x.ChangedAt)
                .ThenByDescending(x => x.Id)
                .Select(x => new WorkHoursChangeResponse
                {
                    Id = x.Id,
                    Action = x.Action.ToString(),
                    ChangedByName = (x.ChangedByUser.Name + " " + x.ChangedByUser.Surname).Trim(),
                    ChangedAt = x.ChangedAt,
                    Before = x.Before,
                    After = x.After,
                })
                .ToListAsync();

        /// <summary>
        /// One correction, in the history and in the admins' and project managers'
        /// notifications - staged here, committed by the caller's one save with the
        /// change itself. Whoever made it is not told about their own change.
        /// </summary>
        private async Task RecordChangeAsync(
            WorkLogDetail? block, int workerId, WorkHoursChangeAction action, string? before, string? after)
        {
            var actorId = _currentUser.Id ?? throw new ForbiddenException("The token carries no user.");

            _dbContext.WorkHoursChanges.Add(new WorkHoursChange
            {
                WorkLogDetail = block,
                WorkerId = workerId,
                ChangedByUserId = actorId,
                ChangedAt = DateTime.UtcNow,
                Action = action,
                Before = before,
                After = after,
            });

            var names = await _dbContext.Users
                .Where(x => x.Id == actorId || x.Id == workerId)
                .Select(x => new { x.Id, Name = (x.Name + " " + x.Surname).Trim() })
                .ToDictionaryAsync(x => x.Id, x => x.Name);
            var actor = names.GetValueOrDefault(actorId, "Someone");
            var worker = names.GetValueOrDefault(workerId, "a worker");

            var (title, message) = action switch
            {
                WorkHoursChangeAction.Added => ("Work hours added", $"{actor} added work hours for {worker}: {after}."),
                WorkHoursChangeAction.Changed => ("Work hours changed", $"{actor} changed {worker}'s work hours: {before} → {after}."),
                _ => ("Work hours deleted", $"{actor} deleted {worker}'s work hours: {before}."),
            };

            await _notifications.StageForRolesAsync(title, message, actorId, Roles.Admin, Roles.ProjectManager);
        }

        /// <summary>
        /// A block in words, the way the history and the notifications show it:
        /// "26-015 Staircase module · Welding · 30.09.2026 07:00-15:00 (8 h)".
        /// Times are Sarajevo's.
        /// </summary>
        private async Task<string> DescribeAsync(WorkLogDetail block)
        {
            var project = await _dbContext.Projects
                .Where(x => x.Id == block.ProjectId)
                .Select(x => (x.Code + " " + x.Name).Trim())
                .FirstOrDefaultAsync() ?? $"Project {block.ProjectId}";
            var operation = await _dbContext.OperationTypes
                .Where(x => x.Id == block.OperationTypeId)
                .Select(x => x.Name)
                .FirstOrDefaultAsync() ?? $"Operation {block.OperationTypeId}";

            var start = SarajevoTime.FromUtc(block.StartedAt);
            var end = block.FinishedAt is { } finished ? SarajevoTime.FromUtc(finished).ToString("HH:mm") : "still running";
            var hours = block.Hours.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture);

            var text = $"{project} · {operation} · {start:dd.MM.yyyy HH:mm}-{end} ({hours} h)";
            return text.Length <= WorkHoursChange.SnapshotMaxLength ? text : text[..WorkHoursChange.SnapshotMaxLength];
        }

        private async Task<WorkLog> FindShiftAsync(int workLogId) =>
            await _dbContext.WorkLogs.FindAsync(workLogId)
            ?? throw new NotFoundException($"WorkLog with id {workLogId} not found.");

        private async Task EnsureBookableAsync(int userId, WorkLogDetailInsertRequest request, int? exceptBlockId)
        {
            await WorkBookingRules.EnsureProjectAllowsBookingAsync(_dbContext, request.ProjectId, request.OperationTypeId);
            await WorkBookingRules.EnsureQualifiedAsync(_dbContext, userId, request.OperationTypeId);
            await WorkBookingRules.EnsureNoOverlapAsync(_dbContext, userId, request.StartedAt, request.FinishedAt, exceptBlockId);
        }

        private static double HoursOf(WorkLogDetailInsertRequest request) =>
            request.FinishedAt is { } finished ? WorkBookingRules.HoursBetween(request.StartedAt, finished) : 0;

        /// <summary>The hours already stored on a shift's blocks, leaving one out.</summary>
        private Task<double> SavedHoursAsync(int workLogId, int? exceptBlockId) => _dbContext.WorkLogDetails
            .Where(x => x.WorkLogId == workLogId && (exceptBlockId == null || x.Id != exceptBlockId))
            .SumAsync(x => x.Hours);

        /// <summary>A shift's hours are its blocks' hours added up - kept so, never taken from a request.</summary>
        private static void RetotalShift(WorkLog shift, double hours) => shift.Hours = Math.Round(hours, 2);

        /// <summary>
        /// The Work Hours screen: filtered, sorted and paged in the database, with
        /// the totals of the whole filtered set alongside the page. Overtime is
        /// read off each block's stored <see cref="WorkLogDetail.RegularHours"/>.
        /// </summary>
        public async Task<WorkHoursPageResponse> GetHoursAsync(WorkHoursSearchObject search)
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

            query = search.HoursFilter switch
            {
                WorkHoursFilter.RegularOnly => query.Where(x => x.Hours <= x.RegularHours),
                WorkHoursFilter.OvertimeOnly => query.Where(x => x.Hours > x.RegularHours),
                WorkHoursFilter.InProgressOnly => query.Where(x => x.FinishedAt == null || x.WorkLog.ClockedOut == null),
                _ => query,
            };

            var totals = await query
                .GroupBy(_ => 1)
                .Select(g => new
                {
                    Count = g.Count(),
                    Total = g.Sum(x => x.Hours),
                    Regular = g.Sum(x => x.RegularHours),
                    Workers = g.Select(x => x.UserId).Distinct().Count(),
                })
                .FirstOrDefaultAsync();

            var items = await SortHours(query, search.SortBy)
                .Skip((search.Page!.Value - 1) * search.PageSize!.Value)
                .Take(search.PageSize.Value)
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
                    x.RegularHours,
                    x.Note,
                    InProgress = x.FinishedAt == null || x.WorkLog.ClockedOut == null,
                })
                .ToListAsync();

            return new WorkHoursPageResponse
            {
                Items = items
                    .Select(x => new WorkHoursEntryResponse
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
                        RegularHours = x.RegularHours,
                        OvertimeHours = Math.Round(x.Hours - x.RegularHours, 2),
                        InProgress = x.InProgress,
                        Note = x.Note,
                    })
                    .ToList(),
                TotalCount = totals?.Count ?? 0,
                TotalHours = Math.Round(totals?.Total ?? 0, 2),
                RegularHours = Math.Round(totals?.Regular ?? 0, 2),
                OvertimeHours = Math.Round((totals?.Total ?? 0) - (totals?.Regular ?? 0), 2),
                WorkerCount = totals?.Workers ?? 0,
            };
        }

        /// <summary>The longest period My Hours may ask for - a little over a month.</summary>
        public const int MaxMyDaysPeriodDays = 62;

        /// <summary>
        /// The signed-in worker's days in a period, a page at a time, newest first.
        /// The database narrows the blocks to this worker and period - at most a
        /// month or so of one person's work - and they are grouped into Sarajevo
        /// days here, which SQL cannot do by time zone.
        /// </summary>
        public async Task<MyWorkDaysResponse> GetMyDaysAsync(MyWorkDaysSearchObject search)
        {
            ClampPaging(search);

            var userId = _currentUser.Id ?? throw new ForbiddenException("The token carries no user.");

            if (search.DateFrom is not { } from || search.DateTo is not { } to || to <= from)
            {
                throw new ClientException("Give the period as a start and a later end.");
            }

            if ((to - from).TotalDays > MaxMyDaysPeriodDays)
            {
                throw new ClientException($"Pick a period of at most {MaxMyDaysPeriodDays} days.");
            }

            var blocks = await _dbContext.WorkLogDetails
                .Where(x => x.UserId == userId && x.StartedAt >= from && x.StartedAt < to)
                .Select(x => new WorkDayBlockResponse
                {
                    Id = x.Id,
                    ProjectId = x.ProjectId,
                    ProjectName = x.Project.Name,
                    ProjectCode = x.Project.Code,
                    OperationName = x.OperationType.Name,
                    StartedAt = x.StartedAt,
                    FinishedAt = x.FinishedAt,
                    Hours = x.Hours,
                    Note = x.Note,
                })
                .ToListAsync();

            var days = blocks
                .GroupBy(x => DateOnly.FromDateTime(SarajevoTime.DayOf(x.StartedAt)))
                .Select(day => new WorkDayResponse
                {
                    Date = day.Key,
                    Hours = Math.Round(day.Sum(x => x.Hours), 2),
                    ProjectCount = day.Select(x => x.ProjectId).Distinct().Count(),
                    InProgress = day.Any(x => x.FinishedAt == null),
                    Blocks = day.OrderBy(x => x.StartedAt).ThenBy(x => x.Id).ToList(),
                })
                .OrderByDescending(x => x.Date)
                .ToList();

            return new MyWorkDaysResponse
            {
                Items = days
                    .Skip((search.Page!.Value - 1) * search.PageSize!.Value)
                    .Take(search.PageSize.Value)
                    .ToList(),
                TotalCount = days.Count,
                TotalHours = Math.Round(blocks.Sum(x => x.Hours), 2),
                ProjectCount = blocks.Select(x => x.ProjectId).Distinct().Count(),
                Trend = days
                    .OrderBy(x => x.Date)
                    .Select(x => new WorkDayTotalResponse { Date = x.Date, Hours = x.Hours, ProjectCount = x.ProjectCount })
                    .ToList(),
            };
        }

        /// <summary>
        /// The Work Hours columns a client may sort by - "Worker", "Project", "Date",
        /// "RegularHours", "OvertimeHours", "TotalHours" or "Status", each optionally
        /// followed by "desc". Newest first when none is given; ties fall back to that.
        /// </summary>
        private static IQueryable<WorkLogDetail> SortHours(IQueryable<WorkLogDetail> query, string? sortBy)
        {
            var tokens = (sortBy ?? string.Empty).Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (tokens.Length == 0)
            {
                return query.OrderByDescending(x => x.StartedAt).ThenByDescending(x => x.Id);
            }

            var descending = tokens.Skip(1).Any(t => t.Equals("desc", StringComparison.OrdinalIgnoreCase));

            IOrderedQueryable<WorkLogDetail> By<TKey>(System.Linq.Expressions.Expression<Func<WorkLogDetail, TKey>> key) =>
                descending ? query.OrderByDescending(key) : query.OrderBy(key);

            var sorted = tokens[0].ToLowerInvariant() switch
            {
                "worker" => descending
                    ? query.OrderByDescending(x => x.User.Name).ThenByDescending(x => x.User.Surname)
                    : query.OrderBy(x => x.User.Name).ThenBy(x => x.User.Surname),
                "project" => By(x => x.Project.Name),
                "date" => By(x => x.StartedAt),
                "regularhours" => By(x => x.RegularHours),
                "overtimehours" => By(x => x.Hours - x.RegularHours),
                "totalhours" => By(x => x.Hours),
                "status" => By(x => x.FinishedAt == null || x.WorkLog.ClockedOut == null),
                _ => throw new ClientException($"Cannot sort work hours by \"{tokens[0]}\"."),
            };

            return sorted.ThenByDescending(x => x.StartedAt).ThenByDescending(x => x.Id);
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

            // "Mine" and a worker's every read are the token's account, never an id
            // the client sent; the office may still look at a chosen worker.
            var userId = _currentUser.IsWorker || search.Mine == true
                ? _currentUser.Id ?? throw new ForbiddenException("The token carries no user.")
                : search.UserId;
            if (userId.HasValue)
            {
                query = query.Where(x => x.UserId == userId.Value);
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
