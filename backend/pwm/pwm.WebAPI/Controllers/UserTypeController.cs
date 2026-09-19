using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Reference data behind the desktop's Administration screen. Also the roster of
    /// roles the whole app authorizes against - see the risk this accepts in
    /// <c>AdministrationRequestValidators</c>.
    /// </summary>
    public class UserTypeController
        : AdminLookupController<UserTypeResponse, UserTypeSearchObject, UserTypeInsertRequest, UserTypeUpdateRequest>
    {
        public UserTypeController(IUserTypeService service) : base(service)
        {
        }
    }
}
