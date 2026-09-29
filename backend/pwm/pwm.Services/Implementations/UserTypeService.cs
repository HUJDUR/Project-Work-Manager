using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class UserTypeService
        : CachedReadService<UserType, UserTypeResponse, UserTypeSearchObject>, IUserTypeService
    {
        public UserTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IMemoryCache cache)
            : base(dbContext, mapper, cache)
        {
        }

        protected override IQueryable<UserType> ApplyFilters(IQueryable<UserType> query, UserTypeSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Type))
            {
                var type = search.Type;
                query = query.Where(x => EF.Functions.Like(x.Type, $"%{type}%"));
            }

            return query;
        }
    }
}
