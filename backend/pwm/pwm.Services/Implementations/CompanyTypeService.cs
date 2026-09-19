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
    public class CompanyTypeService
        : BaseCRUDService<CompanyType, CompanyTypeResponse, CompanyTypeSearchObject, CompanyTypeInsertRequest, CompanyTypeUpdateRequest>, ICompanyTypeService
    {
        public CompanyTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<CompanyTypeInsertRequest> insertValidator,
            IValidator<CompanyTypeUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IQueryable<CompanyType> ApplyFilters(IQueryable<CompanyType> query, CompanyTypeSearchObject? search)
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

            return query;
        }
    }
}
