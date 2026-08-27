using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace pwm.Services
{
    public interface IBaseReadService<TResponse, TSearch>
        where TSearch : BaseSearchObject
    {
        Task<TResponse> GetByIdAsync(int id);
        Task<PageResult<TResponse>> GetAllAsync(TSearch? search = null);
    }
}
