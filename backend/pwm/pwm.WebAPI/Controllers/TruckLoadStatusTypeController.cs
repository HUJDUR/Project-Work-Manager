using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Reference data behind the desktop's Administration screen. Statuses are
    /// matched by <c>Name</c> for their colour chips - see
    /// <c>AdministrationRequestValidators</c>.
    /// </summary>
    public class TruckLoadStatusTypeController
        : AdminLookupController<TruckLoadStatusTypeResponse, TruckLoadStatusTypeSearchObject, TruckLoadStatusTypeInsertRequest, TruckLoadStatusTypeUpdateRequest>
    {
        public TruckLoadStatusTypeController(ITruckLoadStatusTypeService service) : base(service)
        {
        }
    }
}
