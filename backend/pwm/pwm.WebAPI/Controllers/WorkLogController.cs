using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;
using pwm.WebAPI.Services.CurrentUser;

namespace pwm.WebAPI.Controllers
{
    public class WorkLogController : BaseCRUDController<WorkLogResponse, WorkLogSearchObject, WorkLogInsertRequest, WorkLogUpdateRequest>
    {
        private readonly IWorkLogService _workLogService;
        private readonly ICurrentUser _currentUser;

        public WorkLogController(IWorkLogService service, ICurrentUser currentUser) : base(service)
        {
            _workLogService = service;
            _currentUser = currentUser;
        }

        // Clocking in and out is what the mobile app does, so workers write these two -
        // but only for themselves, and the id comes from the token, never from the body.
        [HttpPost]
        [Authorization(Roles.Administrator, Roles.Manager, Roles.Worker)]
        public override Task<WorkLogResponse> Insert([FromBody] WorkLogInsertRequest request)
        {
            request.UserId = OwnerFor(request.UserId);

            return base.Insert(request);
        }

        [HttpPut("{id}")]
        [Authorization(Roles.Administrator, Roles.Manager, Roles.Worker)]
        public override async Task<WorkLogResponse> Update(int id, [FromBody] WorkLogUpdateRequest request)
        {
            await EnsureOwnShiftAsync(id);
            request.UserId = OwnerFor(request.UserId);

            return await base.Update(id, request);
        }

        [HttpDelete("{id}")]
        [Authorization(Roles.Administrator, Roles.Manager, Roles.Worker)]
        public override async Task<IActionResult> Delete(int id)
        {
            await EnsureOwnShiftAsync(id);

            return await base.Delete(id);
        }

        /// <summary>
        /// A worker's shift is their own whatever the body says; the office books anyone's.
        /// </summary>
        private int OwnerFor(int requested)
        {
            if (!_currentUser.IsWorker)
            {
                return requested;
            }

            return _currentUser.Id
                ?? throw new ForbiddenException("The token carries no user, so no shift can be booked.");
        }

        private async Task EnsureOwnShiftAsync(int id)
        {
            if (!_currentUser.IsWorker)
            {
                return;
            }

            var existing = await _workLogService.GetByIdAsync(id);

            if (existing.UserId != _currentUser.Id)
            {
                throw new ForbiddenException("You can only change your own shifts.");
            }
        }
    }
}
