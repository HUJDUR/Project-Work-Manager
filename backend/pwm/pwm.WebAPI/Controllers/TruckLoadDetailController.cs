using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class TruckLoadDetailController : BaseCRUDController<TruckLoadDetailResponse, TruckLoadDetailSearchObject, TruckLoadDetailInsertRequest, TruckLoadDetailUpdateRequest>
    {
        public TruckLoadDetailController(ITruckLoadDetailService service) : base(service)
        {
        }
    }
}
