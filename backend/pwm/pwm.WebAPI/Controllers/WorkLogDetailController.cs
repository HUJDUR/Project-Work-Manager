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
    public class WorkLogDetailController : BaseCRUDController<WorkLogDetailResponse, WorkLogDetailSearchObject, WorkLogDetailInsertRequest, WorkLogDetailUpdateRequest>
    {
        private readonly IWorkLogDetailService _workLogDetailService;
        private readonly IWorkLogService _workLogService;
        private readonly ICurrentUser _currentUser;

        public WorkLogDetailController(
            IWorkLogDetailService service,
            IWorkLogService workLogService,
            ICurrentUser currentUser) : base(service)
        {
            _workLogDetailService = service;
            _workLogService = workLogService;
            _currentUser = currentUser;
        }

        // A worker books their own hours against an operation from the mobile app. The block
        // carries no user of its own, so ownership is the shift it hangs off.
        [HttpPost]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager, Roles.ProductionWorker)]
        public override async Task<WorkLogDetailResponse> Insert([FromBody] WorkLogDetailInsertRequest request)
        {
            await EnsureOwnShiftAsync(request.WorkLogId);

            return await base.Insert(request);
        }

        [HttpPut("{id}")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager, Roles.ProductionWorker)]
        public override async Task<WorkLogDetailResponse> Update(int id, [FromBody] WorkLogDetailUpdateRequest request)
        {
            // Both the block being changed and the shift it is being moved onto.
            await EnsureOwnBlockAsync(id);
            await EnsureOwnShiftAsync(request.WorkLogId);

            return await base.Update(id, request);
        }

        [HttpDelete("{id}")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager, Roles.ProductionWorker)]
        public override async Task<IActionResult> Delete(int id)
        {
            await EnsureOwnBlockAsync(id);

            return await base.Delete(id);
        }

        private async Task EnsureOwnBlockAsync(int id)
        {
            if (!_currentUser.IsWorker)
            {
                return;
            }

            var existing = await _workLogDetailService.GetByIdAsync(id);

            await EnsureOwnShiftAsync(existing.WorkLogId);
        }

        private async Task EnsureOwnShiftAsync(int workLogId)
        {
            if (!_currentUser.IsWorker)
            {
                return;
            }

            var shift = await _workLogService.GetByIdAsync(workLogId);

            if (shift.UserId != _currentUser.Id)
            {
                throw new ForbiddenException("You can only book hours against your own shift.");
            }
        }
    }
}
