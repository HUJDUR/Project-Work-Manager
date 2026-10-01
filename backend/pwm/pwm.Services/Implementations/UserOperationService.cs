using FluentValidation;
using MapsterMapper;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using pwm.Model.Access;
using pwm.Model.Exceptions;

namespace pwm.Services.Implementations
{
    public class UserOperationService
        : BaseCRUDService<UserOperation, UserOperationResponse, UserOperationSearchObject, UserOperationInsertRequest, UserOperationUpdateRequest>, IUserOperationService
    {
        private readonly ICurrentUser _currentUser;

        public UserOperationService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<UserOperationInsertRequest> insertValidator,
            IValidator<UserOperationUpdateRequest> updateValidator,
            ICurrentUser currentUser)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _currentUser = currentUser;
        }

        // The unique (UserId, OperationTypeId) index would otherwise surface as a bare 500.
        public override async Task<UserOperationResponse> InsertAsync(UserOperationInsertRequest request)
        {
            await EnsureNotAlreadyQualifiedAsync(request, exceptId: null);
            return await base.InsertAsync(request);
        }

        public override async Task<UserOperationResponse> UpdateAsync(int id, UserOperationUpdateRequest request)
        {
            await EnsureNotAlreadyQualifiedAsync(request, exceptId: id);
            return await base.UpdateAsync(id, request);
        }

        private async Task EnsureNotAlreadyQualifiedAsync(UserOperationInsertRequest request, int? exceptId)
        {
            var exists = await _dbContext.UserOperations.AnyAsync(x =>
                x.UserId == request.UserId && x.OperationTypeId == request.OperationTypeId && x.Id != exceptId);

            if (exists)
            {
                throw new ClientException("That worker is already qualified for this operation.");
            }
        }

        protected override IQueryable<UserOperation> ApplyFilters(IQueryable<UserOperation> query, UserOperationSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            // "Mine" and a worker's every read are the token's account, never an id
            // the client sent; the office may still look at a chosen worker.
            var userId = _currentUser.IsWorker || search.Mine == true
                ? _currentUser.Id ?? throw new ForbiddenException("The token carries no user.")
                : search.UserId;
            if (userId.HasValue)
            {
                query = query.Where(x => x.UserId == userId.Value);
            }

            if (search.OperationTypeId.HasValue)
            {
                query = query.Where(x => x.OperationTypeId == search.OperationTypeId.Value);
            }

            return query;
        }
    }
}
