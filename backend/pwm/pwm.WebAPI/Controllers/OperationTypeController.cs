using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;

namespace pwm.WebAPI.Controllers
{
    /// <summary>Reference data behind the desktop's Administration screen.</summary>
    public class OperationTypeController
        : AdminLookupController<OperationTypeResponse, OperationTypeSearchObject, OperationTypeInsertRequest, OperationTypeUpdateRequest>
    {
        public OperationTypeController(IOperationTypeService service) : base(service)
        {
        }
    }
}
