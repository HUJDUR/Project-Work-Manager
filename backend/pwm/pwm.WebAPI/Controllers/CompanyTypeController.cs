using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>Reference data behind the desktop's Administration screen.</summary>
    public class CompanyTypeController
        : BaseCRUDController<CompanyTypeResponse, CompanyTypeSearchObject, CompanyTypeInsertRequest, CompanyTypeUpdateRequest>
    {
        public CompanyTypeController(ICompanyTypeService service) : base(service)
        {
        }

        [HttpPost]
        [Authorization(Roles.Admin)]
        public override Task<CompanyTypeResponse> Insert([FromBody] CompanyTypeInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<CompanyTypeResponse> Update(int id, [FromBody] CompanyTypeUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<IActionResult> Delete(int id)
            => base.Delete(id);
    }
}
