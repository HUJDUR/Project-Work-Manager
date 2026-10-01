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
    /// Routes and roles only - which block a write may touch is <see
    /// cref="Services.Implementations.WorkLogDetailService"/>'s call, made against
    /// the caller's id from the token, not this controller's.
    /// </summary>
    public class WorkLogDetailController : BaseCRUDController<WorkLogDetailResponse, WorkLogDetailSearchObject, WorkLogDetailInsertRequest, WorkLogDetailUpdateRequest>
    {
        private readonly IWorkLogDetailService _workLogDetails;

        public WorkLogDetailController(IWorkLogDetailService service) : base(service)
        {
            _workLogDetails = service;
        }

        /// <summary>The desktop's Work Hours screen - the office roles it is open to.</summary>
        [HttpGet("Hours")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager)]
        public Task<WorkHoursPageResponse> Hours([FromQuery] WorkHoursSearchObject searchObject) =>
            _workLogDetails.GetHoursAsync(searchObject);

        /// <summary>
        /// The mobile My Hours screen: the signed-in account's own days - whose
        /// comes from the token, so every role may ask for its own.
        /// </summary>
        [HttpGet("MyDays")]
        public Task<MyWorkDaysResponse> MyDays([FromQuery] MyWorkDaysSearchObject searchObject) =>
            _workLogDetails.GetMyDaysAsync(searchObject);

        /// <summary>The corrections made to one block of work - the same roles as Work Hours.</summary>
        [HttpGet("{id}/History")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager)]
        public Task<List<WorkHoursChangeResponse>> History(int id) => _workLogDetails.GetHistoryAsync(id);

        [HttpPost]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager)]
        public override Task<WorkLogDetailResponse> Insert([FromBody] WorkLogDetailInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager)]
        public override Task<WorkLogDetailResponse> Update(int id, [FromBody] WorkLogDetailUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id}")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager)]
        public override Task<IActionResult> Delete(int id)
            => base.Delete(id);
    }
}
