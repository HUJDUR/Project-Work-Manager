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
    public class OperationTypeService
        : BaseCRUDService<OperationType, OperationTypeResponse, OperationTypeSearchObject, OperationTypeInsertRequest, OperationTypeUpdateRequest>, IOperationTypeService
    {
        public OperationTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<OperationTypeInsertRequest> insertValidator,
            IValidator<OperationTypeUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IEnumerable<OperationType> ApplyFilters(IEnumerable<OperationType> query, OperationTypeSearchObject? search)
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
