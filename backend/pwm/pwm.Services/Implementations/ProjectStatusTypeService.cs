using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class ProjectStatusTypeService
        : CachedReadService<ProjectStatusType, ProjectStatusTypeResponse, ProjectStatusTypeSearchObject>, IProjectStatusTypeService
    {
        public ProjectStatusTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IMemoryCache cache)
            : base(dbContext, mapper, cache)
        {
        }

        protected override IQueryable<ProjectStatusType> ApplyFilters(IQueryable<ProjectStatusType> query, ProjectStatusTypeSearchObject? search)
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
