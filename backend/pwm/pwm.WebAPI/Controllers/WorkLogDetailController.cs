using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class WorkLogDetailController : BaseCRUDController<WorkLogDetailResponse, WorkLogDetailSearchObject, WorkLogDetailInsertRequest, WorkLogDetailUpdateRequest>
    {
        public WorkLogDetailController(IWorkLogDetailService service) : base(service)
        {
        }
    }
}
