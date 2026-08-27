using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class MonthlyHourReportController : BaseReadController<MonthlyHourReportResponse, MonthlyHourReportSearchObject>
    {
        public MonthlyHourReportController(IMonthlyHourReportService service) : base(service)
        {
        }
    }
}
