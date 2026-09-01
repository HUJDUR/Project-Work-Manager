using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;
using pwm.WebAPI.Services.CurrentUser;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Builds the PDFs. Nothing is stored but the request that produced one, so a
    /// download always reflects the current work logs - see <c>GeneratedReport</c>.
    /// </summary>
    [ApiController]
    [Route("[controller]")]
    public class ReportController : ControllerBase
    {
        private readonly IReportService _reportService;
        private readonly ICurrentUser _currentUser;

        public ReportController(IReportService reportService, ICurrentUser currentUser)
        {
            _reportService = reportService;
            _currentUser = currentUser;
        }

        [HttpPost("MonthlyWorkHours")]
        [Authorization(Roles.Administrator, Roles.Manager)]
        public async Task<IActionResult> MonthlyWorkHours(
            [FromBody] MonthlyWorkHoursReportRequest request)
        {
            var content = await _reportService.MonthlyWorkHoursAsync(request, Author());

            return File(content, "application/pdf",
                $"monthly-work-hours-{request.Year}-{request.Month:00}.pdf");
        }

        [HttpPost("TransportLoads")]
        [Authorization(Roles.Administrator, Roles.Manager)]
        public async Task<IActionResult> TransportLoads(
            [FromBody] TransportLoadsReportRequest request)
        {
            var content = await _reportService.TransportLoadsAsync(request, Author());

            return File(content, "application/pdf", "transport-loads.pdf");
        }

        /// <summary>Re-downloads a report from the parameters it was first run with.</summary>
        [HttpGet("{generatedReportId}/Download")]
        [Authorization(Roles.Administrator, Roles.Manager)]
        public async Task<IActionResult> Download(int generatedReportId)
        {
            var (content, fileName) = await _reportService.RerunAsync(generatedReportId);

            return File(content, "application/pdf", fileName);
        }

        /// <summary>
        /// Who generated it comes from the token, never the body. With authentication
        /// bypassed there is no token, so it falls back to the first account.
        /// </summary>
        private int Author() => _currentUser.Id
            ?? (DevSettings.BypassAuthentication
                ? 1
                : throw new ForbiddenException("The token carries no user."));
    }
}
