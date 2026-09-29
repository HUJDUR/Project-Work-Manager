using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Reference data behind the desktop's Administration screen - read-only, like
    /// <c>ActivityLogTypeController</c> and <c>UserTypeController</c>. Several screens
    /// match a row's <c>Name</c> literally: <c>RecommendationService</c> only learns from
    /// projects named "Delivered", and the mobile shop floor's clock-in list and the
    /// desktop dashboard's "active project" rule both key off "In production" - see
    /// <c>ProjectsProvider.deliveredStatus</c>/<c>inProductionStatus</c> and
    /// <c>shop_floor.dart</c>'s <c>liveStatus</c>. Renaming one silently breaks whichever
    /// of those it was; adding one does nothing, since nothing points at it by name.
    /// </summary>
    public class ProjectStatusTypeController
        : BaseReadController<ProjectStatusTypeResponse, ProjectStatusTypeSearchObject>
    {
        public ProjectStatusTypeController(IProjectStatusTypeService service) : base(service)
        {
        }
    }
}
