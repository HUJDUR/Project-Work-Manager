using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    public class ProjectController : BaseCRUDController<ProjectResponse, ProjectSearchObject, ProjectInsertRequest, ProjectUpdateRequest>
    {
        private readonly IProjectService _projects;
        private readonly ICurrentUser _currentUser;

        public ProjectController(IProjectService service, ICurrentUser currentUser) : base(service)
        {
            _projects = service;
            _currentUser = currentUser;
        }

        /// <summary>
        /// The only way <c>ProjectStatusId</c> ever changes - see
        /// <c>ProjectStatusRules</c> for the legal jumps. Admin and Project
        /// manager only: everyone else reads the status, nobody else moves it.
        /// </summary>
        [HttpPatch("{id}/Status")]
        [Authorization(Roles.Admin, Roles.ProjectManager)]
        public async Task<ProjectResponse> ChangeStatus(int id, [FromBody] ProjectStatusChangeRequest request)
        {
            var userId = _currentUser.Id
                ?? throw new ForbiddenException("The token carries no user.");

            return await _projects.ChangeStatusAsync(id, request.ProjectStatusId, request.Reason, userId);
        }

        /// <summary>
        /// Not routed: a project ends in a status ("Delivered" or "Rejected"),
        /// never in a DELETE - that would take its history with it.
        /// </summary>
        [NonAction]
        public override Task<IActionResult> Delete(int id) => base.Delete(id);

        /// <summary>The audit trail behind a project's status - every signed-in
        /// user may read it, the same as the project itself.</summary>
        [HttpGet("{id}/StatusHistory")]
        public Task<List<ProjectStatusChangeResponse>> StatusHistory(int id) =>
            _projects.GetStatusHistoryAsync(id);
    }
}
