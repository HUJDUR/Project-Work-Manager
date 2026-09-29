using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Responses;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>The desktop Dashboard, aggregated in one request - see <c>DashboardService</c>.</summary>
    [ApiController]
    [Route("[controller]")]
    public class DashboardController : ControllerBase
    {
        private readonly IDashboardService _dashboard;
        private readonly ICurrentUser _currentUser;

        public DashboardController(IDashboardService dashboard, ICurrentUser currentUser)
        {
            _dashboard = dashboard;
            _currentUser = currentUser;
        }

        [HttpGet]
        [Authorization(Roles.Admin, Roles.WorkPreparation, Roles.Finances, Roles.ProjectManager)]
        public Task<DashboardResponse> Get() =>
            _dashboard.GetAsync(includeActivity: _currentUser.Role == Roles.Admin);
    }
}
