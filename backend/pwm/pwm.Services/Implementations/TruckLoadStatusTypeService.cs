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
    public class TruckLoadStatusTypeService
        : BaseCRUDService<TruckLoadStatusType, TruckLoadStatusTypeResponse, TruckLoadStatusTypeSearchObject, TruckLoadStatusTypeInsertRequest, TruckLoadStatusTypeUpdateRequest>, ITruckLoadStatusTypeService
    {
        public TruckLoadStatusTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<TruckLoadStatusTypeInsertRequest> insertValidator,
            IValidator<TruckLoadStatusTypeUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IEnumerable<TruckLoadStatusType> ApplyFilters(IEnumerable<TruckLoadStatusType> query, TruckLoadStatusTypeSearchObject? search)
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
