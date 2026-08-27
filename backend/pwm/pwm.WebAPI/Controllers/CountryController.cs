using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class CountryController : BaseReadController<CountryResponse, CountrySearchObject>
    {
        public CountryController(ICountryService service) : base(service)
        {
        }
    }
}
