using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>Reference data behind the desktop's Administration screen.</summary>
    public class OperationTypeController : BaseCRUDController<OperationTypeResponse, OperationTypeSearchObject, OperationTypeInsertRequest, OperationTypeUpdateRequest>
    {
        public OperationTypeController(IOperationTypeService service) : base(service)
        {
        }

        [HttpPost]
        [Authorization(Roles.Admin)]
        public override Task<OperationTypeResponse> Insert([FromBody] OperationTypeInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<OperationTypeResponse> Update(int id, [FromBody] OperationTypeUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<IActionResult> Delete(int id)
            => base.Delete(id);
    }
}
