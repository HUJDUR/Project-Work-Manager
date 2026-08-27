using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class ActivityLogController : BaseReadController<ActivityLogResponse, ActivityLogSearchObject>
    {
        public ActivityLogController(IActivityLogService service) : base(service)
        {
        }
    }
}
