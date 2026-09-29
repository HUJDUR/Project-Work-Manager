using Microsoft.EntityFrameworkCore;
using FluentValidation;
using MapsterMapper;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Business;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class ProjectService
        : BaseCRUDService<Project, ProjectResponse, ProjectSearchObject, ProjectInsertRequest, ProjectUpdateRequest>, IProjectService
    {
        public ProjectService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<ProjectInsertRequest> insertValidator,
            IValidator<ProjectUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        /// <summary>
        /// Every project starts life "Potential", never whatever the caller
        /// sent - the request cannot even express a status or a production
        /// start date any more (see <see cref="ProjectInsertRequest"/>). The
        /// creation itself is the first row of the status history.
        /// </summary>
        public override async Task<ProjectResponse> InsertAsync(ProjectInsertRequest request)
        {
            await _insertValidator.ValidateAndThrowAsync(request);

            var potentialStatus = await _dbContext.ProjectStatusTypes
                    .FirstOrDefaultAsync(x => x.Name == ProjectStatusRules.Potential)
                ?? throw new InvalidOperationException(
                    $"The \"{ProjectStatusRules.Potential}\" project status is missing - reseed the lookup tables.");

            var entity = _mapper.Map<Project>(request);
            entity.ProjectStatusId = potentialStatus.Id;
            entity.ProductionStartDate = null;

            _dbContext.Projects.Add(entity);

            // Through the navigation, not the id: the project has none yet, and EF
            // fixes the key up itself, so both rows commit in one SaveChangesAsync.
            _dbContext.ProjectStatusChanges.Add(new ProjectStatusChange
            {
                Project = entity,
                FromStatusId = null,
                ToStatusId = potentialStatus.Id,
                // Whoever raised it is who put it in this state - no separate
                // "changed by" needed for the row creation itself writes.
                ChangedByUserId = entity.CreatedByUserId,
                ChangedAt = DateTime.UtcNow,
            });
            await _dbContext.SaveChangesAsync();

            return _mapper.Map<ProjectResponse>(entity);
        }

        /// <summary>
        /// <c>ProjectStatusId</c> and <c>ProductionStartDate</c> are never touched
        /// here - the request cannot express either any more, so a plain
        /// <c>_mapper.Map</c> already leaves them alone. What is added on top: a
        /// project sitting in a locked bracket (On hold, Delivered, Rejected)
        /// only ever has its Notes changed, whatever else the request carries.
        /// </summary>
        public override async Task<ProjectResponse> UpdateAsync(int id, ProjectUpdateRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);
            await _updateValidator.ValidateAndThrowAsync(request);

            var entity = await _dbContext.Projects
                    .Include(x => x.ProjectStatus)
                    .FirstOrDefaultAsync(x => x.Id == id)
                ?? throw new NotFoundException($"Project with id {id} not found.");

            if (ProjectStatusRules.IsEditLocked(entity.ProjectStatus.Name))
            {
                entity.Notes = request.Notes;
            }
            else
            {
                _mapper.Map(request, entity);
            }

            await _dbContext.SaveChangesAsync();

            return _mapper.Map<ProjectResponse>(entity);
        }

        /// <summary>
        /// The only door <c>ProjectStatusId</c> ever changes through. Refuses a
        /// jump <see cref="ProjectStatusRules.AllowedNext"/> does not list, sets
        /// <c>ProductionStartDate</c> the moment a project first reaches "In
        /// production", and writes the move to the status history.
        /// </summary>
        public async Task<ProjectResponse> ChangeStatusAsync(int id, int newStatusId, int changedByUserId)
        {
            var entity = await _dbContext.Projects
                    .Include(x => x.ProjectStatus)
                    .FirstOrDefaultAsync(x => x.Id == id)
                ?? throw new NotFoundException($"Project with id {id} not found.");

            var newStatus = await _dbContext.ProjectStatusTypes.FindAsync(newStatusId)
                ?? throw new ClientException("That status does not exist.");

            var allowed = ProjectStatusRules.AllowedNext(
                entity.ProjectStatus.Name, entity.ProductionStartDate != null);

            if (!allowed.Contains(newStatus.Name))
            {
                throw new ClientException(
                    $"A project cannot move from \"{entity.ProjectStatus.Name}\" to \"{newStatus.Name}\".");
            }

            var fromStatusId = entity.ProjectStatusId;
            entity.ProjectStatusId = newStatus.Id;

            if (newStatus.Name == ProjectStatusRules.InProduction && entity.ProductionStartDate == null)
            {
                entity.ProductionStartDate = DateTime.UtcNow;
            }

            _dbContext.ProjectStatusChanges.Add(new ProjectStatusChange
            {
                ProjectId = id,
                FromStatusId = fromStatusId,
                ToStatusId = newStatus.Id,
                ChangedByUserId = changedByUserId,
                ChangedAt = DateTime.UtcNow,
            });

            await _dbContext.SaveChangesAsync();

            return _mapper.Map<ProjectResponse>(entity);
        }

        /// <summary>
        /// Only a project nothing was ever booked against. Hours and transport cargo
        /// are history the shop has to keep, so a project carrying either is refused
        /// with the reason - and pointed at rejecting it - rather than failing on the
        /// foreign key with a generic conflict.
        /// </summary>
        public override async Task DeleteAsync(int id)
        {
            var hasHours = await _dbContext.WorkLogDetails.AnyAsync(x => x.ProjectId == id);
            var hasCargo = await _dbContext.TruckLoadDetails.AnyAsync(x => x.ProjectId == id);

            if (hasHours || hasCargo)
            {
                var booked = (hasHours, hasCargo) switch
                {
                    (true, true) => "work hours and transport cargo",
                    (true, false) => "work hours",
                    _ => "transport cargo",
                };

                throw new ClientException(
                    $"This project has {booked} booked against it, so it cannot be deleted. " +
                    $"Change its status to \"{ProjectStatusRules.Rejected}\" instead.");
            }

            await base.DeleteAsync(id);
        }

        /// <summary>Newest first - the story of how a project got to where it is.</summary>
        public async Task<List<ProjectStatusChangeResponse>> GetStatusHistoryAsync(int projectId)
        {
            return await _dbContext.ProjectStatusChanges
                .Where(x => x.ProjectId == projectId)
                .OrderByDescending(x => x.ChangedAt)
                .Select(x => new ProjectStatusChangeResponse
                {
                    Id = x.Id,
                    FromStatusName = x.FromStatus == null ? null : x.FromStatus.Name,
                    ToStatusName = x.ToStatus.Name,
                    ChangedByUserId = x.ChangedByUserId,
                    ChangedByName = x.ChangedByUser.Name + " " + x.ChangedByUser.Surname,
                    ChangedAt = x.ChangedAt,
                })
                .ToListAsync();
        }

        protected override Task<IQueryable<Project>> IncludeRelatedEntitiesAsync(
            ProjectSearchObject? search, IQueryable<Project> query)
        {
            // Search matches the customer's name too, so that navigation has to be loaded.
            return Task.FromResult<IQueryable<Project>>(query.Include(x => x.Customer));
        }

        protected override IQueryable<Project> ApplyFilters(IQueryable<Project> query, ProjectSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Search))
            {
                var needle = search.Search;
                query = query.Where(x =>
                    EF.Functions.Like(x.Name, $"%{needle}%")
                    || (x.Customer != null && EF.Functions.Like(x.Customer.Name, $"%{needle}%")));
            }

            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                var name = search.Name;
                query = query.Where(x => EF.Functions.Like(x.Name, $"%{name}%"));
            }

            if (search.CustomerId.HasValue)
            {
                query = query.Where(x => x.CustomerId == search.CustomerId.Value);
            }

            if (search.ProjectCategoryId.HasValue)
            {
                query = query.Where(x => x.ProjectCategoryId == search.ProjectCategoryId.Value);
            }

            if (search.ProjectStatusId.HasValue)
            {
                query = query.Where(x => x.ProjectStatusId == search.ProjectStatusId.Value);
            }

            if (search.Priority.HasValue)
            {
                query = query.Where(x => x.Priority == search.Priority.Value);
            }

            if (search.CreatedByUserId.HasValue)
            {
                query = query.Where(x => x.CreatedByUserId == search.CreatedByUserId.Value);
            }

            if (search.DeliveryCompanyId.HasValue)
            {
                query = query.Where(x => x.DeliveryCompanyId == search.DeliveryCompanyId.Value);
            }

            return query;
        }
    }
}
