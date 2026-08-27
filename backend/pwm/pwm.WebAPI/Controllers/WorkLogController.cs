using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class WorkLogController : BaseCRUDController<WorkLogResponse, WorkLogSearchObject, WorkLogInsertRequest, WorkLogUpdateRequest>
    {
        public WorkLogController(IWorkLogService service) : base(service)
        {
        }
    }
}
