using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    public class WorkLogDetailController : BaseCRUDController<WorkLogDetailResponse, WorkLogDetailSearchObject, WorkLogDetailInsertRequest, WorkLogDetailUpdateRequest>
    {
        public WorkLogDetailController(IWorkLogDetailService service) : base(service)
        {
        }

        // A worker books their own hours against an operation from the mobile app
        [HttpPost]
        [Authorization(Roles.Administrator, Roles.Manager, Roles.Worker)]
        public override Task<WorkLogDetailResponse> Insert([FromBody] WorkLogDetailInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Administrator, Roles.Manager, Roles.Worker)]
        public override Task<WorkLogDetailResponse> Update(int id, [FromBody] WorkLogDetailUpdateRequest request)
            => base.Update(id, request);
    }
}
