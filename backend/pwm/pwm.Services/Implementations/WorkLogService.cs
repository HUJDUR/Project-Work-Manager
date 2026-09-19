using FluentValidation;
using MapsterMapper;
using pwm.Model.Access;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class WorkLogService
        : BaseCRUDService<WorkLog, WorkLogResponse, WorkLogSearchObject, WorkLogInsertRequest, WorkLogUpdateRequest>, IWorkLogService
    {
        private readonly ICurrentUser _currentUser;

        public WorkLogService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<WorkLogInsertRequest> insertValidator,
            IValidator<WorkLogUpdateRequest> updateValidator,
            ICurrentUser currentUser)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _currentUser = currentUser;
        }

        // A worker can only write their own shifts; the office can write anyone's.
        public override Task<WorkLogResponse> InsertAsync(WorkLogInsertRequest request)
        {
            request.UserId = OwnerFor(request.UserId);

            return base.InsertAsync(request);
        }

        public override async Task<WorkLogResponse> UpdateAsync(int id, WorkLogUpdateRequest request)
        {
            await EnsureOwnShiftAsync(id);
            request.UserId = OwnerFor(request.UserId);

            return await base.UpdateAsync(id, request);
        }

        public override async Task DeleteAsync(int id)
        {
            await EnsureOwnShiftAsync(id);

            await base.DeleteAsync(id);
        }

        /// <summary>A worker's shift is their own whatever the body says; the office books anyone's.</summary>
        private int OwnerFor(int requested)
        {
            if (!_currentUser.IsWorker)
            {
                return requested;
            }

            return _currentUser.Id
                ?? throw new ForbiddenException("The token carries no user, so no shift can be booked.");
        }

        private async Task EnsureOwnShiftAsync(int id)
        {
            if (!_currentUser.IsWorker)
            {
                return;
            }

            var existing = await GetByIdAsync(id);

            if (existing.UserId != _currentUser.Id)
            {
                throw new ForbiddenException("You can only change your own shifts.");
            }
        }

        protected override IQueryable<WorkLog> ApplyFilters(IQueryable<WorkLog> query, WorkLogSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (search.DateFrom.HasValue)
            {
                query = query.Where(x => x.ClockedIn >= search.DateFrom.Value);
            }

            if (search.DateTo.HasValue)
            {
                query = query.Where(x => x.ClockedIn <= search.DateTo.Value);
            }

            return query;
        }
    }
}
