using pwm.Model.Access;
using pwm.WebAPI.Services.AccessManager;

namespace pwm.WebAPI.Services.CurrentUser
{
    /// <summary>
    /// Reads <see cref="ICurrentUser"/> off the request's claims. The interface lives
    /// in pwm.Model.Access so the service layer can depend on it too; this
    /// implementation stays here because it needs <see cref="IHttpContextAccessor"/>.
    /// </summary>
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

        public bool IsWorker => Role == Roles.ProductionWorker;

        private string? Claim(string type) => _httpContextAccessor.HttpContext?.User?.Claims
            .FirstOrDefault(claim => claim.Type == type)?.Value;
    }
}
