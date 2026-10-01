using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// The Monthly Reports screen: the payroll summary per month, kept up to date by
    /// the server as work is booked. Admins and project managers.
    /// </summary>
    public class MonthlyHourReportController : BaseReadController<MonthlyHourReportResponse, MonthlyHourReportSearchObject>
    {
        private readonly IMonthlyHourReportService _reports;

        public MonthlyHourReportController(IMonthlyHourReportService service) : base(service)
        {
            _reports = service;
        }

        [HttpGet]
        [Authorization(Roles.Admin, Roles.ProjectManager)]
        public override Task<PageResult<MonthlyHourReportResponse>> GetAll([FromQuery] MonthlyHourReportSearchObject? searchObject)
            => base.GetAll(searchObject);

        [HttpGet("{id}")]
        [Authorization(Roles.Admin, Roles.ProjectManager)]
        public override Task<MonthlyHourReportResponse> GetById(int id) => base.GetById(id);

        /// <summary>One month opened: every worker's hours and the hours per work type.</summary>
        [HttpGet("{id}/Overview")]
        [Authorization(Roles.Admin, Roles.ProjectManager)]
        public Task<MonthlyHourReportOverviewResponse> Overview(int id) => _reports.GetOverviewAsync(id);
    }
}
