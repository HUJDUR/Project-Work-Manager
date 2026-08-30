using pwm.Model.Access;

namespace pwm.WebAPI.Services.AccessManager
{
    public interface IAccessManager
    {
        Task<UserLoginResponse> LoginAsync(UserLoginRequest request);

        Task<UserLoginResponse> LoginWithRefreshTokenAsync(RefreshAccessTokenRequest request);

        Task LogoutAsync(RefreshAccessTokenRequest request);
    }
}
