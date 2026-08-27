using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class UserTypeController : BaseReadController<UserTypeResponse, UserTypeSearchObject>
    {
        public UserTypeController(IUserTypeService service) : base(service)
        {
        }
    }
}
