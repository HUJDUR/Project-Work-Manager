using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class ActivityLogService
        : BaseReadService<ActivityLog, ActivityLogResponse, ActivityLogSearchObject>, IActivityLogService
    {
        public ActivityLogService(PWMDbContext dbContext, IMapper mapper)
            : base(mapper, dbContext)
        {
        }

        public async Task RecordAsync(int userId, string activityLogTypeName)
        {
            var logType = await _dbContext.ActivityLogTypes
                .FirstOrDefaultAsync(x => x.Name == activityLogTypeName);

            if (logType is null)
            {
                return;
            }

            // Tracked, not saved - see the interface doc: the caller's own
            // SaveChangesAsync is what commits this, alongside whatever else it did.
            _dbContext.ActivityLogs.Add(new ActivityLog
            {
                UserId = userId,
                ActivityLogTypeId = logType.Id,
                Date = DateTime.UtcNow,
            });
        }

        protected override IQueryable<ActivityLog> ApplyFilters(IQueryable<ActivityLog> query, ActivityLogSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Search))
            {
                var needle = search.Search.Trim();
                query = query.Where(x => EF.Functions.Like(x.User.Name + " " + x.User.Surname, $"%{needle}%"));
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (search.ActivityLogTypeId.HasValue)
            {
                query = query.Where(x => x.ActivityLogTypeId == search.ActivityLogTypeId.Value);
            }

            if (search.GeneratedReportId.HasValue)
            {
                query = query.Where(x => x.GeneratedReportId == search.GeneratedReportId.Value);
            }

            if (search.DateFrom.HasValue)
            {
                query = query.Where(x => x.Date >= search.DateFrom.Value);
            }

            if (search.DateTo.HasValue)
            {
                query = query.Where(x => x.Date <= search.DateTo.Value);
            }

            return query;
        }

        /// <summary>
        /// Besides the entity's own columns, "User" (by name) and "Activity" (by type
        /// name), each optionally followed by "desc" - ties newest first.
        /// </summary>
        protected override IQueryable<ActivityLog> ApplySorting(IQueryable<ActivityLog> query, string sortBy)
        {
            var tokens = sortBy.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            var descending = tokens.Skip(1).Any(t => t.Equals("desc", StringComparison.OrdinalIgnoreCase));

            IOrderedQueryable<ActivityLog>? sorted = tokens[0].ToLowerInvariant() switch
            {
                "user" => descending
                    ? query.OrderByDescending(x => x.User.Name).ThenByDescending(x => x.User.Surname)
                    : query.OrderBy(x => x.User.Name).ThenBy(x => x.User.Surname),
                "activity" => descending
                    ? query.OrderByDescending(x => x.ActivityLogType.Name)
                    : query.OrderBy(x => x.ActivityLogType.Name),
                _ => null,
            };

            return sorted is null
                ? base.ApplySorting(query, sortBy)
                : sorted.ThenByDescending(x => x.Date).ThenByDescending(x => x.Id);
        }
    }
}
