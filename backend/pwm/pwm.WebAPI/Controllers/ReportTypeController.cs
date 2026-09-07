using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class ReportTypeController : BaseReadController<ReportTypeResponse, ReportTypeSearchObject>
    {
        public ReportTypeController(IReportTypeService service) : base(service)
        {
        }
    }
}
