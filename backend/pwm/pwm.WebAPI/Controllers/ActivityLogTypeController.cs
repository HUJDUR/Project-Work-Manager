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
    public class ActivityLogTypeController
        : BaseCRUDController<ActivityLogTypeResponse, ActivityLogTypeSearchObject, ActivityLogTypeInsertRequest, ActivityLogTypeUpdateRequest>
    {
        public ActivityLogTypeController(IActivityLogTypeService service) : base(service)
        {
        }

        // Reading is open to every signed-in user; writing lookup tables is
        // narrowed to the one role the Administration screen is open to - the
        // same technique UserController uses over its own three writes.
        [HttpPost]
        [Authorization(Roles.Admin)]
        public override Task<ActivityLogTypeResponse> Insert([FromBody] ActivityLogTypeInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<ActivityLogTypeResponse> Update(int id, [FromBody] ActivityLogTypeUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<IActionResult> Delete(int id)
            => base.Delete(id);
    }
}
