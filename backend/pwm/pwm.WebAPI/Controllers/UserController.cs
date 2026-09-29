using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    public class UserController : BaseCRUDController<UserResponse, UserSearchObject, UserInsertRequest, UserUpdateRequest>
    {
        private readonly IUserService _users;
        private readonly ICurrentUser _currentUser;

        public UserController(IUserService service, ICurrentUser currentUser) : base(service)
        {
            _users = service;
            _currentUser = currentUser;
        }

        /// <summary>
        /// The account settings screen. Open to any signed-in user because it can
        /// only ever touch their **own** row: the id comes from the token, and
        /// <see cref="UserProfileUpdateRequest"/> cannot express a role or an
        /// active flag, so this is not a way around the administrator-only writes
        /// below.
        /// </summary>
        [HttpPut("Me")]
        public async Task<UserResponse> UpdateMe([FromBody] UserProfileUpdateRequest request)
        {
            var id = _currentUser.Id
                ?? throw new ForbiddenException("The token carries no user.");

            return await _users.UpdateProfileAsync(id, request);
        }

        // Accounts carry the roles everything else is authorized by, so only an administrator edits them
        [HttpPost]
        [Authorization(Roles.Admin)]
        public override Task<UserResponse> Insert([FromBody] UserInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<UserResponse> Update(int id, [FromBody] UserUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<IActionResult> Delete(int id)
            => base.Delete(id);
    }
}
