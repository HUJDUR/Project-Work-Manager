using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using pwm.WebAPI.Services.AccessManager;

namespace pwm.WebAPI.Filters
{
    /// <summary>
    /// Restricts an action to the listed roles, read from the token's <see cref="ClaimNames.Role"/> claim.
    /// Authentication itself is handled by the fallback policy in <c>Program.cs</c>.
    /// </summary>
    public class AuthorizationAttribute : TypeFilterAttribute
    {
        public AuthorizationAttribute(params string[] roles) : base(typeof(AuthorizationFilter))
        {
            Arguments = [roles];
        }

        public class AuthorizationFilter : IAuthorizationFilter
        {
            private readonly string[] _roles;

            public AuthorizationFilter(string[] roles)
            {
                _roles = roles;
            }

            public void OnAuthorization(AuthorizationFilterContext context)
            {
                if (DevSettings.BypassAuthentication)
                {
                    return;
                }

                var role = context.HttpContext.User.Claims
                    .FirstOrDefault(c => c.Type == ClaimNames.Role)?.Value;

                if (role == null || !_roles.Contains(role))
                {
                    context.Result = new ForbidResult();
                }
            }
        }
    }
}
