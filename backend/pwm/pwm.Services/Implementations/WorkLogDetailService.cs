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
    public class WorkLogDetailService
        : BaseCRUDService<WorkLogDetail, WorkLogDetailResponse, WorkLogDetailSearchObject, WorkLogDetailInsertRequest, WorkLogDetailUpdateRequest>, IWorkLogDetailService
    {
        private readonly ICurrentUser _currentUser;

        public WorkLogDetailService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<WorkLogDetailInsertRequest> insertValidator,
            IValidator<WorkLogDetailUpdateRequest> updateValidator,
            ICurrentUser currentUser)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _currentUser = currentUser;
        }

        // A block has no user of its own; ownership is the shift it belongs to.
        public override async Task<WorkLogDetailResponse> InsertAsync(WorkLogDetailInsertRequest request)
        {
            await EnsureOwnShiftAsync(request.WorkLogId);

            return await base.InsertAsync(request);
        }

        public override async Task<WorkLogDetailResponse> UpdateAsync(int id, WorkLogDetailUpdateRequest request)
        {
            // Both the block being changed and the shift it is being moved onto.
            await EnsureOwnBlockAsync(id);
            await EnsureOwnShiftAsync(request.WorkLogId);

            return await base.UpdateAsync(id, request);
        }

        public override async Task DeleteAsync(int id)
        {
            await EnsureOwnBlockAsync(id);

            await base.DeleteAsync(id);
        }

        private async Task EnsureOwnBlockAsync(int id)
        {
            if (!_currentUser.IsWorker)
            {
                return;
            }

            var existing = await GetByIdAsync(id);

            await EnsureOwnShiftAsync(existing.WorkLogId);
        }

        private async Task EnsureOwnShiftAsync(int workLogId)
        {
            if (!_currentUser.IsWorker)
            {
                return;
            }

            var shift = await _dbContext.WorkLogs.FindAsync(workLogId)
                ?? throw new NotFoundException($"WorkLog with id {workLogId} not found.");

            if (shift.UserId != _currentUser.Id)
            {
                throw new ForbiddenException("You can only book hours against your own shift.");
            }
        }

        protected override IQueryable<WorkLogDetail> ApplyFilters(IQueryable<WorkLogDetail> query, WorkLogDetailSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.WorkLogId.HasValue)
            {
                query = query.Where(x => x.WorkLogId == search.WorkLogId.Value);
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (search.ProjectId.HasValue)
            {
                query = query.Where(x => x.ProjectId == search.ProjectId.Value);
            }

            if (search.OperationTypeId.HasValue)
            {
                query = query.Where(x => x.OperationTypeId == search.OperationTypeId.Value);
            }

            if (search.DateFrom.HasValue)
            {
                query = query.Where(x => x.StartedAt >= search.DateFrom.Value);
            }

            if (search.DateTo.HasValue)
            {
                query = query.Where(x => x.StartedAt <= search.DateTo.Value);
            }

            return query;
        }
    }
}
