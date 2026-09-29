using FluentValidation;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Business;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class TruckLoadDetailService
        : BaseCRUDService<TruckLoadDetail, TruckLoadDetailResponse, TruckLoadDetailSearchObject, TruckLoadDetailInsertRequest, TruckLoadDetailUpdateRequest>, ITruckLoadDetailService
    {
        public TruckLoadDetailService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<TruckLoadDetailInsertRequest> insertValidator,
            IValidator<TruckLoadDetailUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        public override async Task<TruckLoadDetailResponse> InsertAsync(TruckLoadDetailInsertRequest request)
        {
            await EnsureProjectAllowsBookingAsync(request.ProjectId);
            await EnsureTruckLoadAllowsCargoAsync(request.TruckLoadId);

            return await base.InsertAsync(request);
        }

        public override async Task<TruckLoadDetailResponse> UpdateAsync(int id, TruckLoadDetailUpdateRequest request)
        {
            await EnsureProjectAllowsBookingAsync(request.ProjectId);
            await EnsureTruckLoadAllowsCargoAsync(request.TruckLoadId);

            return await base.UpdateAsync(id, request);
        }

        public override async Task DeleteAsync(int id)
        {
            var existing = await GetByIdAsync(id);
            await EnsureTruckLoadAllowsCargoAsync(existing.TruckLoadId);

            await base.DeleteAsync(id);
        }

        /// <summary>A project not actively worked (On hold, Delivered, Rejected)
        /// takes no new transports either - see <see cref="ProjectStatusRules"/>.</summary>
        private async Task EnsureProjectAllowsBookingAsync(int projectId)
        {
            var project = await _dbContext.Projects
                    .Include(x => x.ProjectStatus)
                    .FirstOrDefaultAsync(x => x.Id == projectId)
                ?? throw new NotFoundException($"Project with id {projectId} not found.");

            if (!ProjectStatusRules.CanBookAnything(project.ProjectStatus.Name))
            {
                throw new ClientException(
                    $"A \"{project.ProjectStatus.Name}\" project cannot have new transports booked against it.");
            }
        }

        /// <summary>Cargo can only be added, changed or removed while the load
        /// itself is still Ordered - see <see cref="TruckLoadStatusRules"/>.</summary>
        private async Task EnsureTruckLoadAllowsCargoAsync(int truckLoadId)
        {
            var truckLoad = await _dbContext.TruckLoads
                    .Include(x => x.TruckLoadStatus)
                    .FirstOrDefaultAsync(x => x.Id == truckLoadId)
                ?? throw new NotFoundException($"TruckLoad with id {truckLoadId} not found.");

            if (!TruckLoadStatusRules.CanEditCargo(truckLoad.TruckLoadStatus.Name))
            {
                throw new ClientException(
                    $"Cargo cannot be changed on a \"{truckLoad.TruckLoadStatus.Name}\" transport.");
            }
        }

        protected override IQueryable<TruckLoadDetail> ApplyFilters(IQueryable<TruckLoadDetail> query, TruckLoadDetailSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.TruckLoadId.HasValue)
            {
                query = query.Where(x => x.TruckLoadId == search.TruckLoadId.Value);
            }

            if (search.ProjectId.HasValue)
            {
                query = query.Where(x => x.ProjectId == search.ProjectId.Value);
            }

            return query;
        }
    }
}
