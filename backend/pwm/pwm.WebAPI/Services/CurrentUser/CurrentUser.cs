using System.Security.Claims;
using pwm.Model.Access;
using pwm.WebAPI.Services.AccessManager;

namespace pwm.WebAPI.Services.CurrentUser
{
    /// <summary>
    /// Who is calling, read from the token rather than from the route or the body.
    /// Anything a user does to their own data resolves the id through this.
    /// </summary>
    public interface ICurrentUser
    {
        int? Id { get; }

        string? Role { get; }

        /// <summary>Shop floor: may write their own work logs and nobody else's.</summary>
        bool IsWorker { get; }
    }

    public class CurrentUser : ICurrentUser
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public CurrentUser(IHttpContextAccessor httpContextAccessor)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public int? Id =>
            int.TryParse(Claim(ClaimNames.Id), out var id) ? id : null;

        public string? Role => Claim(ClaimNames.Role);

        // With authentication bypassed there is no token to read, so nothing is
        // narrowed to an owner - the same escape hatch AuthorizationFilter takes.
        public bool IsWorker => !DevSettings.BypassAuthentication && Role == Roles.Worker;

        private string? Claim(string type) => _httpContextAccessor.HttpContext?.User?.Claims
            .FirstOrDefault(claim => claim.Type == type)?.Value;
    }
}
