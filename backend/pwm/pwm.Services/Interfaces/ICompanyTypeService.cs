using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services.Interfaces
{
    public interface ICompanyTypeService : IBaseCRUDService<CompanyTypeResponse, CompanyTypeSearchObject, CompanyTypeInsertRequest, CompanyTypeUpdateRequest>
    {
    }
}
