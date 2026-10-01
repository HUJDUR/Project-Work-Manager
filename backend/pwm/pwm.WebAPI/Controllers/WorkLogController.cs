using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Routes and roles only - clocking in and out, and which shifts a caller may
    /// read, are <see cref="Services.Implementations.WorkLogService"/>'s call, made
    /// against the caller's id from the token.
    /// </summary>
    public class WorkLogController : BaseCRUDController<WorkLogResponse, WorkLogSearchObject, WorkLogInsertRequest, WorkLogUpdateRequest>
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

        // Shifts are written by hand only by the office, correcting or adding
        // hours; the shop floor goes through ClockIn/ClockOut.
        [HttpPost]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager)]
        public override Task<WorkLogResponse> Insert([FromBody] WorkLogInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager)]
        public override Task<WorkLogResponse> Update(int id, [FromBody] WorkLogUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id}")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager)]
        public override Task<IActionResult> Delete(int id)
            => base.Delete(id);
    }
}
