using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.WebAPI.Services.AccessManager;

namespace pwm.WebAPI.Controllers
{
    /// <summary>Sign-in, token refresh, sign-out and password-reset requests. The only
    /// endpoints reachable without a token.</summary>
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

        /// <summary>
        /// "Reset password" on the login screen, for someone who cannot sign in to ask
        /// for anything themselves. Always answers 204, whether or not the identifier
        /// belongs to an account - see <see cref="IAccessManager.RequestPasswordResetAsync"/>.
        /// </summary>
        [AllowAnonymous]
        [HttpPost("RequestPasswordReset")]
        public async Task<IActionResult> RequestPasswordReset([FromBody] PasswordResetRequest request)
        {
            await _accessManager.RequestPasswordResetAsync(request);
            return NoContent();
        }
    }
}
