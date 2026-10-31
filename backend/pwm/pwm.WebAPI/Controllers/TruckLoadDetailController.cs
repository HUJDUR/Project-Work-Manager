using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    public class TruckLoadDetailController : BaseCRUDController<TruckLoadDetailResponse, TruckLoadDetailSearchObject, TruckLoadDetailInsertRequest, TruckLoadDetailUpdateRequest>
    {
        public TruckLoadDetailController(ITruckLoadDetailService service) : base(service)
        {
        }

        /// <summary>Cargo is read by the office, the same roles as the transports it is on.</summary>
        [HttpGet]
        [Authorization(Roles.Admin, Roles.WorkPreparation, Roles.Finances, Roles.ProjectManager)]
        public override Task<PageResult<TruckLoadDetailResponse>> GetAll([FromQuery] TruckLoadDetailSearchObject? searchObject)
            => base.GetAll(searchObject);

        [HttpGet("{id}")]
        [Authorization(Roles.Admin, Roles.WorkPreparation, Roles.Finances, Roles.ProjectManager)]
        public override Task<TruckLoadDetailResponse> GetById(int id) => base.GetById(id);
    }
}
