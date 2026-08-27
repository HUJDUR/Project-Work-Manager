using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class NotificationController : BaseReadController<NotificationResponse, NotificationSearchObject>
    {
        public NotificationController(INotificationService service) : base(service)
        {
        }
    }
}
