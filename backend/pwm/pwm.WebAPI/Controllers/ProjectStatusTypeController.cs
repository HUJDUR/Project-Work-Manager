using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class ProjectStatusTypeController : BaseReadController<ProjectStatusTypeResponse, ProjectStatusTypeSearchObject>
    {
        public ProjectStatusTypeController(IProjectStatusTypeService service) : base(service)
        {
        }
    }
}
