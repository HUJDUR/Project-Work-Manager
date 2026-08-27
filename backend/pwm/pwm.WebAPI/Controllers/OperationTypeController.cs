using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    public class OperationTypeController : BaseCRUDController<OperationTypeResponse, OperationTypeSearchObject, OperationTypeInsertRequest, OperationTypeUpdateRequest>
    {
        public OperationTypeController(IOperationTypeService service) : base(service)
        {
        }
    }
}
