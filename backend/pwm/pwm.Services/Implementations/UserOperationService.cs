using FluentValidation;
using MapsterMapper;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class UserOperationService
        : BaseCRUDService<UserOperation, UserOperationResponse, UserOperationSearchObject, UserOperationInsertRequest, UserOperationUpdateRequest>, IUserOperationService
    {
        public UserOperationService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<UserOperationInsertRequest> insertValidator,
            IValidator<UserOperationUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IQueryable<UserOperation> ApplyFilters(IQueryable<UserOperation> query, UserOperationSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (search.OperationTypeId.HasValue)
            {
                query = query.Where(x => x.OperationTypeId == search.OperationTypeId.Value);
            }

            return query;
        }
    }
}
