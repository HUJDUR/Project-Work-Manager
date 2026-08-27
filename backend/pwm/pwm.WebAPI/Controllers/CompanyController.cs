using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class CompanyController : BaseCRUDController<CompanyResponse, CompanySearchObject, CompanyInsertRequest, CompanyUpdateRequest>
    {
        public CompanyController(ICompanyService service) : base(service)
        {
        }
    }
}
