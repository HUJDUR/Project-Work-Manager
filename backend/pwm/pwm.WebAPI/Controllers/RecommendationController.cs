using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Requests;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Project Resource Estimation - the office's aid for sizing a project before it starts.
    /// One action, nothing stored: see <see cref="Services.Implementations.RecommendationService"/>.
    /// </summary>
    [ApiController]
    [Route("[controller]")]
    public class RecommendationController : ControllerBase
    {
        private readonly IRecommendationService _recommendationService;

        public RecommendationController(IRecommendationService recommendationService)
        {
            _recommendationService = recommendationService;
        }

        // Same three roles the desktop's Recommendations screen is open to - Finances
        // has no business estimating shop-floor work, and it never sees this screen.
        [HttpPost("Estimate")]
        [Authorization(Roles.Admin, Roles.WorkPreparation, Roles.ProjectManager)]
        public async Task<IActionResult> Estimate([FromBody] RecommendationRequest request)
        {
            return Ok(await _recommendationService.EstimateAsync(request));
        }
    }
}
