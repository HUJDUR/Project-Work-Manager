using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services.Interfaces
{
    public interface ITruckLoadDetailService : IBaseCRUDService<TruckLoadDetailResponse, TruckLoadDetailSearchObject, TruckLoadDetailInsertRequest, TruckLoadDetailUpdateRequest>
    {
    }
}
