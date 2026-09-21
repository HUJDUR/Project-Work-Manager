using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Reference data behind the desktop's Administration screen - read-only, like
    /// <c>ActivityLogTypeController</c>. Its <c>Type</c> column is the roster of roles the
    /// whole app authorizes against (see <c>Roles</c> and <c>AuthorizationAttribute</c>),
    /// matched by string, not by id: renaming one here would lock every account of that
    /// role out of everything it used to be authorized for, and adding one would do
    /// nothing, since no <c>[Authorization]</c> attribute anywhere names it.
    /// </summary>
    public class UserTypeController
        : BaseReadController<UserTypeResponse, UserTypeSearchObject>
    {
        public UserTypeController(IUserTypeService service) : base(service)
        {
        }
    }
}
