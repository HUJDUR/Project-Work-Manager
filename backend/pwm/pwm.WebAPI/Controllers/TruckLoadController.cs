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
        /// The only way <c>TruckLoadStatusId</c> ever changes - see
        /// <c>TruckLoadStatusRules</c> for the legal jumps. Admin and Project
        /// manager only: everyone else reads the status, nobody else moves it.
        /// </summary>
        [HttpPatch("{id}/Status")]
        [Authorization(Roles.Admin, Roles.ProjectManager)]
        public Task<TruckLoadResponse> ChangeStatus(int id, [FromBody] TruckLoadStatusChangeRequest request) =>
            _truckLoads.ChangeStatusAsync(id, request.TruckLoadStatusId, request.Price);

        /// <summary>The audit trail behind a transport's status - every signed-in
        /// user may read it, the same as the load itself.</summary>
        [HttpGet("{id}/StatusHistory")]
        public Task<List<TruckLoadStatusChangeResponse>> StatusHistory(int id) =>
            _truckLoads.GetStatusHistoryAsync(id);
    }
}
