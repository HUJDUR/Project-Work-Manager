using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class ActivityLogTypeService
        : CachedReadService<ActivityLogType, ActivityLogTypeResponse, ActivityLogTypeSearchObject>, IActivityLogTypeService
    {
        public ActivityLogTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IMemoryCache cache)
            : base(dbContext, mapper, cache)
        {
        }

        protected override IQueryable<ActivityLogType> ApplyFilters(IQueryable<ActivityLogType> query, ActivityLogTypeSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                var name = search.Name;
                query = query.Where(x => EF.Functions.Like(x.Name, $"%{name}%"));
            }

            return query;
        }
    }
}
