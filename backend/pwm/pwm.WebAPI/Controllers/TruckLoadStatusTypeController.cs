using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class TruckLoadStatusTypeController : BaseReadController<TruckLoadStatusTypeResponse, TruckLoadStatusTypeSearchObject>
    {
        public TruckLoadStatusTypeController(ITruckLoadStatusTypeService service) : base(service)
        {
        }
    }
}
