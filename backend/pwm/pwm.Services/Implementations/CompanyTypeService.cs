using System;
using System.Collections.Generic;
using System.Linq;
using FluentValidation;
using MapsterMapper;
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

        protected override IEnumerable<CompanyType> ApplyFilters(IEnumerable<CompanyType> query, CompanyTypeSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                var name = search.Name;
                query = query.Where(x => x.Name.Contains(name, StringComparison.OrdinalIgnoreCase));
            }

            return query;
        }
    }
}
