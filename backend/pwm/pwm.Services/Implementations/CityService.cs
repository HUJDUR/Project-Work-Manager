using FluentValidation;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class CityService
        : CachedLookupService<City, CityResponse, CitySearchObject, CityInsertRequest, CityUpdateRequest>, ICityService
    {
        public CityService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<CityInsertRequest> insertValidator,
            IValidator<CityUpdateRequest> updateValidator,
            IMemoryCache cache)
            : base(dbContext, mapper, insertValidator, updateValidator, cache)
        {
        }

        protected override IQueryable<City> ApplyFilters(IQueryable<City> query, CitySearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                var name = search.Name;
                query = query.Where(x => EF.Functions.Like(x.Name, $"%{name}%"));
            }

            if (!string.IsNullOrWhiteSpace(search.PostalCode))
            {
                var postalCode = search.PostalCode;
                query = query.Where(x => EF.Functions.Like(x.PostalCode, $"%{postalCode}%"));
            }

            if (search.CountryId.HasValue)
            {
                query = query.Where(x => x.CountryId == search.CountryId.Value);
            }

            return query;
        }
    }
}
