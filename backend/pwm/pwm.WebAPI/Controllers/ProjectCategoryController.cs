using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class ProjectCategoryController : BaseCRUDController<ProjectCategoryResponse, ProjectCategorySearchObject, ProjectCategoryInsertRequest, ProjectCategoryUpdateRequest>
    {
        public ProjectCategoryController(IProjectCategoryService service) : base(service)
        {
        }
    }
}
