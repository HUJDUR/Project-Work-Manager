using pwm.Model.Access;

namespace pwm.WebAPI.Services.AccessManager
{
    public interface IAccessManager
    {
        Task<UserLoginResponse> LoginAsync(UserLoginRequest request);

        Task<UserLoginResponse> LoginWithRefreshTokenAsync(RefreshAccessTokenRequest request);

        Task LogoutAsync(RefreshAccessTokenRequest request);

        /// <summary>
        /// The "Reset password" link on the login screen. Never reveals whether the
        /// identifier belongs to an account - the controller answers the same way
        /// either way, which is why this returns nothing to branch on.
        /// </summary>
        Task RequestPasswordResetAsync(PasswordResetRequest request);
    }
}
