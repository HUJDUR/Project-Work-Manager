using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.WebAPI.Services.AccessManager;

namespace pwm.WebAPI.Controllers
{
    /// <summary>Sign-in, token refresh and sign-out. The only endpoints reachable without a token.</summary>
    [ApiController]
    [Route("[controller]")]
    public class AccessController : ControllerBase
    {
        private readonly IAccessManager _accessManager;

        public AccessController(IAccessManager accessManager)
        {
            _accessManager = accessManager;
        }

        [AllowAnonymous]
        [HttpPost("Login")]
        public async Task<UserLoginResponse> Login([FromBody] UserLoginRequest request)
        {
            return await _accessManager.LoginAsync(request);
        }

        [AllowAnonymous]
        [HttpPost("LoginWithRefreshToken")]
        public async Task<UserLoginResponse> LoginWithRefreshToken([FromBody] RefreshAccessTokenRequest request)
        {
            return await _accessManager.LoginWithRefreshTokenAsync(request);
        }

        [HttpPost("Logout")]
        public async Task<IActionResult> Logout([FromBody] RefreshAccessTokenRequest request)
        {
            await _accessManager.LogoutAsync(request);
            return NoContent();
        }
    }
}
