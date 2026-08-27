using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class CityController : BaseReadController<CityResponse, CitySearchObject>
    {
        public CityController(ICityService service) : base(service)
        {
        }
    }
}
