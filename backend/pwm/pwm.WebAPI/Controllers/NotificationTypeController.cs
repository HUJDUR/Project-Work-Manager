using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>Reference data behind the desktop's Administration screen.</summary>
    public class NotificationTypeController
        : AdminLookupController<NotificationTypeResponse, NotificationTypeSearchObject, NotificationTypeInsertRequest, NotificationTypeUpdateRequest>
    {
        public NotificationTypeController(INotificationTypeService service) : base(service)
        {
        }
    }
}
