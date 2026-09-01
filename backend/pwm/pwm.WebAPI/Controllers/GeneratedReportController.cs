using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// The "Recent Reports" list. Rows are written by <c>ReportController</c> when a
    /// report is produced, never through this controller.
    /// </summary>
    public class GeneratedReportController : BaseReadController<GeneratedReportResponse, GeneratedReportSearchObject>
    {
        public GeneratedReportController(IGeneratedReportService service) : base(service)
        {
        }
    }
}
