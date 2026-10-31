using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// The "Recent Reports" list - for the roles the Reports screen is open to. Rows
    /// are written by <c>ReportController</c> when a report is produced, never through
    /// this controller, and which kinds a role may see is the service's call.
    /// </summary>
    public class GeneratedReportController : BaseReadController<GeneratedReportResponse, GeneratedReportSearchObject>
    {
        public GeneratedReportController(IGeneratedReportService service) : base(service)
        {
        }

        [HttpGet]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager)]
        public override Task<PageResult<GeneratedReportResponse>> GetAll([FromQuery] GeneratedReportSearchObject? searchObject)
            => base.GetAll(searchObject);

        [HttpGet("{id}")]
        [Authorization(Roles.Admin, Roles.Finances, Roles.ProjectManager)]
        public override Task<GeneratedReportResponse> GetById(int id) => base.GetById(id);
    }
}
