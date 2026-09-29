using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class ReportTypeService
        : CachedReadService<ReportType, ReportTypeResponse, ReportTypeSearchObject>, IReportTypeService
    {
        public ReportTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IMemoryCache cache)
            : base(dbContext, mapper, cache)
        {
        }

        protected override IQueryable<ReportType> ApplyFilters(IQueryable<ReportType> query, ReportTypeSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Description))
            {
                var description = search.Description;
                query = query.Where(x => EF.Functions.Like(x.Description, $"%{description}%"));
            }

            return query;
        }
    }
}
