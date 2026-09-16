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
    /// Reference data behind the desktop's Administration screen. Statuses are
    /// matched by <c>Name</c> for their colour chips - see
    /// <c>AdministrationRequestValidators</c>.
    /// </summary>
    public class TruckLoadStatusTypeController
        : BaseCRUDController<TruckLoadStatusTypeResponse, TruckLoadStatusTypeSearchObject, TruckLoadStatusTypeInsertRequest, TruckLoadStatusTypeUpdateRequest>
    {
        public TruckLoadStatusTypeController(ITruckLoadStatusTypeService service) : base(service)
        {
        }

        [HttpPost]
        [Authorization(Roles.Admin)]
        public override Task<TruckLoadStatusTypeResponse> Insert([FromBody] TruckLoadStatusTypeInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<TruckLoadStatusTypeResponse> Update(int id, [FromBody] TruckLoadStatusTypeUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<IActionResult> Delete(int id)
            => base.Delete(id);
    }
}
