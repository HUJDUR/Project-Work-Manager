using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Reference data behind the desktop's Administration screen. The status life
    /// cycle in <c>TruckLoadStatusRules</c> matches rows by <c>Name</c> ("Ordered",
    /// "Delivered", "Finished", "Rejected"), as do the desktop's colour chips, so
    /// renaming one of those four breaks transport creation and status changes.
    /// </summary>
    public class TruckLoadStatusTypeController
        : AdminLookupController<TruckLoadStatusTypeResponse, TruckLoadStatusTypeSearchObject, TruckLoadStatusTypeInsertRequest, TruckLoadStatusTypeUpdateRequest>
    {
        public TruckLoadStatusTypeController(ITruckLoadStatusTypeService service) : base(service)
        {
        }
    }
}
