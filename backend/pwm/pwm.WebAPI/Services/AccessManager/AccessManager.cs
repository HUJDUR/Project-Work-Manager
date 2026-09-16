using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.IdentityModel.Tokens;
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
        private readonly IConfiguration _configuration;

        public AccessManager(
            IUserService userService,
            IRefreshTokenService refreshTokenService,
            IConfiguration configuration)
        {
            _userService = userService;
            _refreshTokenService = refreshTokenService;
            _configuration = configuration;
        }

        public async Task<UserLoginResponse> LoginAsync(UserLoginRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
            {
                throw new ClinetException("Email and password are required.");
            }

            var authenticated = await _userService.AuthenticateAsync(request.Email.Trim(), request.Password);

            // Same message for an unknown email and a wrong password: it must not say which
            if (authenticated == null)
            {
                throw new ClinetException("Incorrect email or password.");
            }

            return await IssueTokensAsync(authenticated);
        }

        public async Task<UserLoginResponse> LoginWithRefreshTokenAsync(RefreshAccessTokenRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.RefreshToken))
            {
                throw new ClinetException("Refresh token is required.");
            }

            var stored = await _refreshTokenService.GetStoredTokenAsync(request.RefreshToken);

            if (stored == null)
            {
                throw new ClinetException("Invalid refresh token.");
            }

            if (stored.ExpiresAt < DateTime.UtcNow)
            {
                throw new ClinetException("Your session has expired. Please sign in again.");
            }

            var authenticated = await _userService.GetAuthenticatedUserAsync(stored.UserId);

            if (authenticated == null)
            {
                throw new ClinetException("Invalid refresh token.");
            }

            return await IssueTokensAsync(authenticated);
        }

        public async Task LogoutAsync(RefreshAccessTokenRequest request)
        {
            var stored = string.IsNullOrWhiteSpace(request.RefreshToken)
                ? null
                : await _refreshTokenService.GetStoredTokenAsync(request.RefreshToken);

            // Signing out with an already unknown token is not an error
            if (stored != null)
            {
                await _refreshTokenService.DeleteAllUserRefreshTokensAsync(stored.UserId);
            }
        }

        private async Task<UserLoginResponse> IssueTokensAsync(AuthenticatedUser authenticated)
        {
            if (!authenticated.User.IsActive)
            {
                throw new ClinetException("This account is deactivated. Contact an administrator.");
            }

            var (accessToken, expiresAt) = GenerateAccessToken(authenticated);
            var refreshToken = GenerateRefreshToken();

            // One live refresh token per user: the old one dies with the session it belonged to
            await _refreshTokenService.DeleteAllUserRefreshTokensAsync(authenticated.User.Id);
            await _refreshTokenService.IssueAsync(
                authenticated.User.Id,
                refreshToken,
                DateTime.UtcNow.AddDays(RefreshTokenDurationInDays));

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
            // The signing key is a secret, so it comes from JWT_SECRET in backend/.env
            // alone - the same resolution Program.cs's AddJwtAuthentication uses to
            // validate the tokens this issues, never from appsettings.json.
            var secretKey = Environment.GetEnvironmentVariable("JWT_SECRET");

            if (string.IsNullOrWhiteSpace(secretKey))
            {
                throw new InvalidOperationException("JWT_SECRET is not set - add it to backend/.env.");
            }

            var expiresAt = DateTime.UtcNow.AddMinutes(AccessTokenDurationInMinutes);

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
                ]),
                Expires = expiresAt,
                Issuer = _configuration["JwtToken:Issuer"],
                Audience = _configuration["JwtToken:Audience"],
                SigningCredentials = new SigningCredentials(
                    new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey)),
                    SecurityAlgorithms.HmacSha256Signature),
            };

            var handler = new JwtSecurityTokenHandler();

            return (handler.WriteToken(handler.CreateToken(tokenDescriptor)), expiresAt);
        }

        private int AccessTokenDurationInMinutes =>
            int.TryParse(_configuration["JwtToken:DurationInMinutes"], out var minutes) ? minutes : 60;

        private int RefreshTokenDurationInDays =>
            int.TryParse(_configuration["JwtToken:RefreshTokenDurationInDays"], out var days) ? days : 7;

        private static string GenerateRefreshToken() =>
            Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
    }
}
