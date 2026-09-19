using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Queues a report; <c>pwm.Worker</c> is the separate process that actually
    /// builds the PDF, off RabbitMQ. Nothing here waits for it - poll <c>Status</c>
    /// and call <c>Download</c> once it answers "Completed".
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

        // A project manager reads transports only - the monthly hours report is not theirs.
        [HttpPost("MonthlyWorkHours")]
        [Authorization(Roles.Admin, Roles.Finances)]
        public async Task<ActionResult<ReportQueuedResponse>> MonthlyWorkHours(
            [FromBody] MonthlyWorkHoursReportRequest request)
        {
            var queued = await _reportService.MonthlyWorkHoursAsync(request, Author());

            return Accepted(queued);
        }

        [HttpPost("TransportLoads")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager)]
        public async Task<ActionResult<ReportQueuedResponse>> TransportLoads(
            [FromBody] TransportLoadsReportRequest request)
        {
            var queued = await _reportService.TransportLoadsAsync(request, Author());

            return Accepted(queued);
        }

        /// <summary>What the Reports screen polls while a PDF is being built.</summary>
        [HttpGet("{generatedReportId}/Status")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager)]
        public async Task<ReportStatusResponse> Status(int generatedReportId)
        {
            return await _reportService.GetStatusAsync(generatedReportId, _currentUser.Role);
        }

        /// <summary>
        /// The attribute cannot see which report this is, so narrowing a project
        /// manager away from a monthly hours report happens in the service instead.
        /// </summary>
        [HttpGet("{generatedReportId}/Download")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager)]
        public async Task<IActionResult> Download(int generatedReportId)
        {
            var (content, fileName) = await _reportService.DownloadAsync(generatedReportId, _currentUser.Role);

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
