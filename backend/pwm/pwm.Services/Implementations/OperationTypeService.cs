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

        protected override IQueryable<OperationType> ApplyFilters(IQueryable<OperationType> query, OperationTypeSearchObject? search)
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
