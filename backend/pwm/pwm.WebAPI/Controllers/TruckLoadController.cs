using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    public class TruckLoadController : BaseCRUDController<TruckLoadResponse, TruckLoadSearchObject, TruckLoadInsertRequest, TruckLoadUpdateRequest>
    {
        private readonly ITruckLoadService _truckLoads;

        public TruckLoadController(ITruckLoadService service) : base(service)
        {
            _truckLoads = service;
        }

        /// <summary>
        /// The office reads transports - the shop floor's app has no use for loads
        /// and their invoiced prices.
        /// </summary>
        [HttpGet]
        [Authorization(Roles.Admin, Roles.WorkPreparation, Roles.Finances, Roles.ProjectManager)]
        public override Task<PageResult<TruckLoadResponse>> GetAll([FromQuery] TruckLoadSearchObject? searchObject)
            => base.GetAll(searchObject);

        [HttpGet("{id}")]
        [Authorization(Roles.Admin, Roles.WorkPreparation, Roles.Finances, Roles.ProjectManager)]
        public override Task<TruckLoadResponse> GetById(int id) => base.GetById(id);

        /// <summary>
        /// The only way <c>TruckLoadStatusId</c> ever changes - see
        /// <c>TruckLoadStatusRules</c> for the legal jumps. Admin and Project
        /// manager only: everyone else reads the status, nobody else moves it.
        /// </summary>
        [HttpPatch("{id}/Status")]
        [Authorization(Roles.Admin, Roles.ProjectManager)]
        public Task<TruckLoadResponse> ChangeStatus(int id, [FromBody] TruckLoadStatusChangeRequest request) =>
            _truckLoads.ChangeStatusAsync(id, request.TruckLoadStatusId, request.Price, request.Reason);

        /// <summary>
        /// Not routed: a transport ends in a status ("Finished" or "Rejected"),
        /// never in a DELETE - that would take its history with it.
        /// </summary>
        [NonAction]
        public override Task<IActionResult> Delete(int id) => base.Delete(id);

        /// <summary>The audit trail behind a transport's status - for whoever may
        /// read the load itself.</summary>
        [HttpGet("{id}/StatusHistory")]
        [Authorization(Roles.Admin, Roles.WorkPreparation, Roles.Finances, Roles.ProjectManager)]
        public Task<List<TruckLoadStatusChangeResponse>> StatusHistory(int id) =>
            _truckLoads.GetStatusHistoryAsync(id);
    }
}
