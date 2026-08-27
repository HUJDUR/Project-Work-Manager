using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class CompanyTypeController : BaseReadController<CompanyTypeResponse, CompanyTypeSearchObject>
    {
        public CompanyTypeController(ICompanyTypeService service) : base(service)
        {
        }
    }
}
