using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class TruckLoadController : BaseCRUDController<TruckLoadResponse, TruckLoadSearchObject, TruckLoadInsertRequest, TruckLoadUpdateRequest>
    {
        public TruckLoadController(ITruckLoadService service) : base(service)
        {
        }
    }
}
