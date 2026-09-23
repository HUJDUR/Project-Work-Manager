using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Who did what and when, across every account - an audit trail, so reading it
    /// is narrowed to administrators alone rather than left open the way the other
    /// read-only lookups under <see cref="BaseReadController{TResponse, TSearch}"/> are.
    /// </summary>
    public class ActivityLogController : BaseReadController<ActivityLogResponse, ActivityLogSearchObject>
    {
        public ActivityLogController(IActivityLogService service) : base(service)
        {
        }

        [HttpGet]
        [Authorization(Roles.Admin)]
        public override Task<PageResult<ActivityLogResponse>> GetAll([FromQuery] ActivityLogSearchObject? searchObject)
            => base.GetAll(searchObject);

        [HttpGet("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<ActivityLogResponse> GetById(int id)
            => base.GetById(id);
    }
}
