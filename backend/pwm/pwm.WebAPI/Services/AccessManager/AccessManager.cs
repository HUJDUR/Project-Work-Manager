using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using pwm.Common.Services.Hosting;
using pwm.Model.Access;
using pwm.Model.Exceptions;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Services.AccessManager
{
    /// <summary>
    /// Issues the access token every other endpoint is authorized by, and rotates the
    /// refresh token that buys a new one once the access token expires.
    /// </summary>
    public class AccessManager : IAccessManager
    {
        private readonly IUserService _userService;
        private readonly IRefreshTokenService _refreshTokenService;
        private readonly IActivityLogService _activityLogService;
        private readonly INotificationService _notificationService;
        private readonly string _jwtSecret;
        private readonly string _jwtIssuer;
        private readonly string _jwtAudience;
        private readonly int _accessTokenDurationInMinutes;
        private readonly int _refreshTokenDurationInDays;

        public AccessManager(
            IUserService userService,
            IRefreshTokenService refreshTokenService,
            IActivityLogService activityLogService,
            INotificationService notificationService)
        {
            _userService = userService;
            _refreshTokenService = refreshTokenService;
            _activityLogService = activityLogService;
            _notificationService = notificationService;

            // All from backend/.env - the same values Program.cs's AddJwtAuthentication
            // validates the tokens this issues against. Read once here rather than on
            // every token issued.
            _jwtSecret = EnvironmentConfig.Require("JWT_SECRET");
            _jwtIssuer = EnvironmentConfig.Require("JwtToken__Issuer");
            _jwtAudience = EnvironmentConfig.Require("JwtToken__Audience");
            _accessTokenDurationInMinutes = int.Parse(EnvironmentConfig.Require("JwtToken__DurationInMinutes"));
            _refreshTokenDurationInDays = int.Parse(EnvironmentConfig.Require("JwtToken__RefreshTokenDurationInDays"));
        }

        public async Task<UserLoginResponse> LoginAsync(UserLoginRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.EmailOrUsername) || string.IsNullOrWhiteSpace(request.Password))
            {
                throw new ClientException("Email/username and password are required.");
            }

            var authenticated = await _userService.AuthenticateAsync(request.EmailOrUsername.Trim(), request.Password);

            // Same message for an unknown identifier and a wrong password: it must not say which
            if (authenticated == null)
            {
                throw new ClientException("Incorrect email/username or password.");
            }

            // Recorded here, not inside IssueTokensAsync: LoginWithRefreshTokenAsync shares
            // that method too, and a silent token refresh is not a fresh "Log In". Staged
            // first, so the refresh-token rotation's own save commits it alongside.
            await _activityLogService.RecordAsync(authenticated.User.Id, ActivityLogTypeNames.LogIn);

            return await IssueTokensAsync(authenticated);
        }

        public async Task<UserLoginResponse> LoginWithRefreshTokenAsync(RefreshAccessTokenRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.RefreshToken))
            {
                throw new ClientException("Refresh token is required.");
            }

            var stored = await _refreshTokenService.GetStoredTokenAsync(request.RefreshToken);

            if (stored == null)
            {
                throw new ClientException("Invalid refresh token.");
            }

            if (stored.ExpiresAt < DateTime.UtcNow)
            {
                throw new ClientException("Your session has expired. Please sign in again.");
            }

            var authenticated = await _userService.GetAuthenticatedUserAsync(stored.UserId);

            if (authenticated == null)
            {
                throw new ClientException("Invalid refresh token.");
            }

            return await IssueTokensAsync(authenticated);
        }

        public async Task LogoutAsync(RefreshAccessTokenRequest request)
        {
            var stored = string.IsNullOrWhiteSpace(request.RefreshToken)
                ? null
                : await _refreshTokenService.GetStoredTokenAsync(request.RefreshToken);

            // Signing out with an already unknown token is not an error
            // SignOutAsync also bumps the token version, so the access token this
            // session was still holding - unexpired, and otherwise usable - is rejected
            // by OnTokenValidated on its very next use, not only once it expires.
            if (stored != null)
            {
                await _userService.SignOutAsync(stored.UserId);
            }
        }

        public async Task RequestPasswordResetAsync(PasswordResetRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.EmailOrUsername))
            {
                throw new ClientException("Enter your e-mail or username first.");
            }

            var user = await _userService.FindByEmailOrUsernameAsync(request.EmailOrUsername.Trim());

            // Same account-enumeration guard Login's own error message already
            // follows: nothing here reveals whether that identifier belongs to
            // anyone, so an unknown one is refused no differently than a known one
            // that just quietly notifies the office.
            if (user == null)
            {
                return;
            }

            await _notificationService.NotifyAdminsOfPasswordResetRequestAsync(
                user.Id, $"{user.Name} {user.Surname}".Trim(), user.Email);
        }

        private async Task<UserLoginResponse> IssueTokensAsync(AuthenticatedUser authenticated)
        {
            if (!authenticated.User.IsActive)
            {
                throw new ClientException("This account is deactivated. Contact an administrator.");
            }

            var (accessToken, expiresAt) = GenerateAccessToken(authenticated);
            var refreshToken = GenerateRefreshToken();

            // One live refresh token per user: the old one dies with the session it
            // belonged to. RotateAsync does both in one SaveChangesAsync, so a crash
            // between the two can never leave the account with neither.
            await _refreshTokenService.RotateAsync(
                authenticated.User.Id,
                refreshToken,
                DateTime.UtcNow.AddDays(_refreshTokenDurationInDays));

            return new UserLoginResponse
            {
                Accesstoken = accessToken,
                Refreshtoken = refreshToken,
                ExpiresAt = expiresAt,
                Role = authenticated.Role,
                User = authenticated.User,
            };
        }

        private (string Token, DateTime ExpiresAt) GenerateAccessToken(AuthenticatedUser authenticated)
        {
            var user = authenticated.User;
            var expiresAt = DateTime.UtcNow.AddMinutes(_accessTokenDurationInMinutes);

            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(
                [
                    new Claim(ClaimNames.Id, user.Id.ToString()),
                    new Claim(ClaimNames.Name, user.Name),
                    new Claim(ClaimNames.Surname, user.Surname),
                    new Claim(ClaimNames.Email, user.Email),
                    new Claim(ClaimNames.Role, authenticated.Role),
                    new Claim(ClaimNames.IsActive, user.IsActive.ToString()),
                    new Claim(ClaimNames.TokenVersion, authenticated.TokenVersion.ToString()),
                ]),
                Expires = expiresAt,
                Issuer = _jwtIssuer,
                Audience = _jwtAudience,
                SigningCredentials = new SigningCredentials(
                    new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtSecret)),
                    SecurityAlgorithms.HmacSha256Signature),
            };

            var handler = new JwtSecurityTokenHandler();

            return (handler.WriteToken(handler.CreateToken(tokenDescriptor)), expiresAt);
        }

        private static string GenerateRefreshToken() =>
            Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
    }
}
