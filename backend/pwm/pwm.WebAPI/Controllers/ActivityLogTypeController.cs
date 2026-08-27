using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class ActivityLogTypeController : BaseReadController<ActivityLogTypeResponse, ActivityLogTypeSearchObject>
    {
        public ActivityLogTypeController(IActivityLogTypeService service) : base(service)
        {
        }
    }
}
