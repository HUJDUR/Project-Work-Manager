using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Reference data behind the desktop's Administration screen - read-only, unlike the
    /// other ten tables there. Each of the six rows is matched by name from application
    /// code that writes an <c>ActivityLog</c> (see <c>AccessManager</c>, <c>NotificationService</c>,
    /// <c>ReportService</c>), so a row added here would never actually get used, and one
    /// renamed or deleted would silently stop that code from logging anything at all.
    /// </summary>
    public class ActivityLogTypeController
        : BaseReadController<ActivityLogTypeResponse, ActivityLogTypeSearchObject>
    {
        public ActivityLogTypeController(IActivityLogTypeService service) : base(service)
        {
        }
    }
}
