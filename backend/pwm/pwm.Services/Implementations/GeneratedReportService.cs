using MapsterMapper;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class GeneratedReportService
        : BaseReadService<GeneratedReport, GeneratedReportResponse, GeneratedReportSearchObject>, IGeneratedReportService
    {
        public GeneratedReportService(PWMDbContext dbContext, IMapper mapper)
            : base(mapper, dbContext)
        {
        }

        protected override IQueryable<GeneratedReport> ApplyFilters(IQueryable<GeneratedReport> query, GeneratedReportSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.ReportTypeId.HasValue)
            {
                query = query.Where(x => x.ReportTypeId == search.ReportTypeId.Value);
            }

            return query;
        }
    }
}
