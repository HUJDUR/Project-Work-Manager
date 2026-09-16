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
    /// Reference data behind the desktop's Administration screen. Its rows mirror
    /// <c>pwm.Model.Enums.ReportType</c> - see <c>ReportTypeInsertRequest</c> for
    /// what that means for a row added here.
    /// </summary>
    public class ReportTypeController
        : BaseCRUDController<ReportTypeResponse, ReportTypeSearchObject, ReportTypeInsertRequest, ReportTypeUpdateRequest>
    {
        public ReportTypeController(IReportTypeService service) : base(service)
        {
        }

        [HttpPost]
        [Authorization(Roles.Admin)]
        public override Task<ReportTypeResponse> Insert([FromBody] ReportTypeInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<ReportTypeResponse> Update(int id, [FromBody] ReportTypeUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<IActionResult> Delete(int id)
            => base.Delete(id);
    }
}
