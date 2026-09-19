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
    /// Routes and roles only - which block a write may touch is <see
    /// cref="Services.Implementations.WorkLogDetailService"/>'s call, made against
    /// the caller's id from the token, not this controller's.
    /// </summary>
    public class WorkLogDetailController : BaseCRUDController<WorkLogDetailResponse, WorkLogDetailSearchObject, WorkLogDetailInsertRequest, WorkLogDetailUpdateRequest>
    {
        public WorkLogDetailController(IWorkLogDetailService service) : base(service)
        {
        }

        [HttpPost]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager, Roles.ProductionWorker)]
        public override Task<WorkLogDetailResponse> Insert([FromBody] WorkLogDetailInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager, Roles.ProductionWorker)]
        public override Task<WorkLogDetailResponse> Update(int id, [FromBody] WorkLogDetailUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id}")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager, Roles.ProductionWorker)]
        public override Task<IActionResult> Delete(int id)
            => base.Delete(id);
    }
}
