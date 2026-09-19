using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Reference data behind the desktop's Administration screen. Its rows mirror
    /// <c>pwm.Model.Enums.ReportType</c> - see <c>ReportTypeInsertRequest</c> for
    /// what that means for a row added here.
    /// </summary>
    public class ReportTypeController
        : AdminLookupController<ReportTypeResponse, ReportTypeSearchObject, ReportTypeInsertRequest, ReportTypeUpdateRequest>
    {
        public ReportTypeController(IReportTypeService service) : base(service)
        {
        }
    }
}
