using FluentValidation;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class CompanyService
        : BaseCRUDService<Company, CompanyResponse, CompanySearchObject, CompanyInsertRequest, CompanyUpdateRequest>, ICompanyService
    {
        public CompanyService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<CompanyInsertRequest> insertValidator,
            IValidator<CompanyUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IQueryable<Company> ApplyFilters(IQueryable<Company> query, CompanySearchObject? search)
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

            if (search.CountryId.HasValue)
            {
                query = query.Where(x => x.CountryId == search.CountryId.Value);
            }

            if (search.CityId.HasValue)
            {
                query = query.Where(x => x.CityId == search.CityId.Value);
            }

            if (search.CompanyTypeId.HasValue)
            {
                query = query.Where(x => x.CompanyTypeId == search.CompanyTypeId.Value);
            }

            return query;
        }
    }
}
