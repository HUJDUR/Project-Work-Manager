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
    /// Routes and roles only - which shift a write may touch is <see
    /// cref="Services.Implementations.WorkLogService"/>'s call, made against the
    /// caller's id from the token, not this controller's.
    /// </summary>
    public class WorkLogController : BaseCRUDController<WorkLogResponse, WorkLogSearchObject, WorkLogInsertRequest, WorkLogUpdateRequest>
    {
        public WorkLogController(IWorkLogService service) : base(service)
        {
        }

        // Clocking in and out is what the mobile app does, so workers write these two.
        [HttpPost]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager, Roles.ProductionWorker)]
        public override Task<WorkLogResponse> Insert([FromBody] WorkLogInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager, Roles.ProductionWorker)]
        public override Task<WorkLogResponse> Update(int id, [FromBody] WorkLogUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id}")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager, Roles.ProductionWorker)]
        public override Task<IActionResult> Delete(int id)
            => base.Delete(id);
    }
}
