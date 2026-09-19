using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Reference data behind the desktop's Administration screen. Several screens
    /// match a row's <c>Name</c> literally (the mobile shop-floor filter, the
    /// dashboard's "active project" rule) - see <c>AdministrationRequestValidators</c>.
    /// </summary>
    public class ProjectStatusTypeController
        : AdminLookupController<ProjectStatusTypeResponse, ProjectStatusTypeSearchObject, ProjectStatusTypeInsertRequest, ProjectStatusTypeUpdateRequest>
    {
        public ProjectStatusTypeController(IProjectStatusTypeService service) : base(service)
        {
        }
    }
}
