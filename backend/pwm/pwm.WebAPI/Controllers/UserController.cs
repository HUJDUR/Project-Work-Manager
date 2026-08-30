using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    public class UserController : BaseCRUDController<UserResponse, UserSearchObject, UserInsertRequest, UserUpdateRequest>
    {
        public UserController(IUserService service) : base(service)
        {
        }

        // Accounts carry the roles everything else is authorized by, so only an administrator edits them
        [HttpPost]
        [Authorization(Roles.Administrator)]
        public override Task<UserResponse> Insert([FromBody] UserInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Administrator)]
        public override Task<UserResponse> Update(int id, [FromBody] UserUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id}")]
        [Authorization(Roles.Administrator)]
        public override Task<IActionResult> Delete(int id)
            => base.Delete(id);
    }
}
