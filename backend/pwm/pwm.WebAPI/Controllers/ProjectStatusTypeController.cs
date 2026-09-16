using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Reference data behind the desktop's Administration screen. Several screens
    /// match a row's <c>Name</c> literally (the mobile shop-floor filter, the
    /// dashboard's "active project" rule) - see <c>AdministrationRequestValidators</c>.
    /// </summary>
    public class ProjectStatusTypeController
        : BaseCRUDController<ProjectStatusTypeResponse, ProjectStatusTypeSearchObject, ProjectStatusTypeInsertRequest, ProjectStatusTypeUpdateRequest>
    {
        public ProjectStatusTypeController(IProjectStatusTypeService service) : base(service)
        {
        }

        [HttpPost]
        [Authorization(Roles.Admin)]
        public override Task<ProjectStatusTypeResponse> Insert([FromBody] ProjectStatusTypeInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<ProjectStatusTypeResponse> Update(int id, [FromBody] ProjectStatusTypeUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<IActionResult> Delete(int id)
            => base.Delete(id);
    }
}
