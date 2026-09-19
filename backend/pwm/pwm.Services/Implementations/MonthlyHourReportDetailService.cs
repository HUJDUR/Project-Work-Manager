using MapsterMapper;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class MonthlyHourReportDetailService
        : BaseReadService<MonthlyHourReportDetail, MonthlyHourReportDetailResponse, MonthlyHourReportDetailSearchObject>, IMonthlyHourReportDetailService
    {
        public MonthlyHourReportDetailService(PWMDbContext dbContext, IMapper mapper)
            : base(mapper, dbContext)
        {
        }

        protected override IQueryable<MonthlyHourReportDetail> ApplyFilters(IQueryable<MonthlyHourReportDetail> query, MonthlyHourReportDetailSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.MonthlyHourReportId.HasValue)
            {
                query = query.Where(x => x.MonthlyHourReportId == search.MonthlyHourReportId.Value);
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            return query;
        }
    }
}
