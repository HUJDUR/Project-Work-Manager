using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Reference data behind the desktop's Administration screen - read-only, like
    /// <c>ActivityLogTypeController</c> and <c>UserTypeController</c>. Its rows mirror
    /// <c>pwm.Model.Enums.ReportType</c> by id, and <c>ReportService.QueueAsync</c> builds
    /// the matching "Generated report - ..." activity log type name from a row's
    /// <c>Description</c> live, on every report queued - rename one and reports of that
    /// kind silently stop being logged. Adding a row is not meaningfully possible either:
    /// the id has to be one of the two <c>ReportType</c> enum values, both already taken.
    /// </summary>
    public class ReportTypeController
        : BaseReadController<ReportTypeResponse, ReportTypeSearchObject>
    {
        public ReportTypeController(IReportTypeService service) : base(service)
        {
        }
    }
}
