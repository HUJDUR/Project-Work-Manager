using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Reference data behind the desktop's Administration screen - read-only, like
    /// <c>ProjectStatusTypeController</c>. The transport life cycle in
    /// <c>TruckLoadStatusRules</c> matches these rows by <c>Name</c> ("Ordered",
    /// "Delivered", "Finished", "Rejected"): renaming one would break creating a
    /// transport and moving it on, and adding one would do nothing, since no rule
    /// names it.
    /// </summary>
    public class TruckLoadStatusTypeController
        : BaseReadController<TruckLoadStatusTypeResponse, TruckLoadStatusTypeSearchObject>
    {
        public TruckLoadStatusTypeController(ITruckLoadStatusTypeService service) : base(service)
        {
        }
    }
}
