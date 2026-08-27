using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class MonthlyHourReportDetailController : BaseReadController<MonthlyHourReportDetailResponse, MonthlyHourReportDetailSearchObject>
    {
        public MonthlyHourReportDetailController(IMonthlyHourReportDetailService service) : base(service)
        {
        }
    }
}
