using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    public class WorkLogController : BaseCRUDController<WorkLogResponse, WorkLogSearchObject, WorkLogInsertRequest, WorkLogUpdateRequest>
    {
        public WorkLogController(IWorkLogService service) : base(service)
        {
        }

        // Clocking in and out is what the mobile app does, so workers write these two
        [HttpPost]
        [Authorization(Roles.Administrator, Roles.Manager, Roles.Worker)]
        public override Task<WorkLogResponse> Insert([FromBody] WorkLogInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Administrator, Roles.Manager, Roles.Worker)]
        public override Task<WorkLogResponse> Update(int id, [FromBody] WorkLogUpdateRequest request)
            => base.Update(id, request);
    }
}
