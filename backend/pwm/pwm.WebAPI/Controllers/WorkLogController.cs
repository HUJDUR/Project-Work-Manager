using Microsoft.AspNetCore.Mvc;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Routes only - clocking in and out, and which shifts a caller may read, are
    /// <see cref="Services.Implementations.WorkLogService"/>'s call, made against the
    /// caller's id from the token. Shifts have no write routes of their own: they are
    /// worked out from their blocks, which the office books through <c>WorkLogDetail</c>.
    /// </summary>
    public class WorkLogController : BaseReadController<WorkLogResponse, WorkLogSearchObject>
    {
        private readonly IWorkLogService _workLogs;

        public WorkLogController(IWorkLogService service) : base(service)
        {
            _workLogs = service;
        }

        /// <summary>The Clock In screen: the running session, projects, qualified operations.</summary>
        [HttpGet("ClockIn")]
        public Task<ClockInOptionsResponse> ClockInOptions() => _workLogs.GetClockInOptionsAsync();

        /// <summary>
        /// Clocking in and out - open to every signed-in role, since the office books
        /// its own hours on the phone too. Who and when come from the token and the
        /// server's clock; the phone only says what.
        /// </summary>
        [HttpPost("ClockIn")]
        public Task<ClockSessionResponse> ClockIn([FromBody] ClockInRequest request) =>
            _workLogs.ClockInAsync(request);

        [HttpPost("ClockOut")]
        public Task<ClockSessionResponse> ClockOut() => _workLogs.ClockOutAsync();
    }
}
