using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services.Interfaces
{
    public interface ICountryService : IBaseReadService<CountryResponse, CountrySearchObject>
    {
    }
}
