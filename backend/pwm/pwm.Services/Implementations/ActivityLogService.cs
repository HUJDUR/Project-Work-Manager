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
    }
}
