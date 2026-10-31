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
using pwm.Model.Access;

namespace pwm.Services.Implementations
{
    public class ProjectService
        : BaseCRUDService<Project, ProjectResponse, ProjectSearchObject, ProjectInsertRequest, ProjectUpdateRequest>, IProjectService
    {
        private readonly INotificationService _notifications;
        private readonly ICurrentUser _currentUser;

        public ProjectService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<ProjectInsertRequest> insertValidator,
            IValidator<ProjectUpdateRequest> updateValidator,
            INotificationService notifications,
            ICurrentUser currentUser)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _notifications = notifications;
            _currentUser = currentUser;
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

            await CompanyRules.EnsureSelectableAsync(_dbContext, request.CustomerId, null, "customer");
            await CompanyRules.EnsureSelectableAsync(_dbContext, request.DeliveryCompanyId, null, "delivery company");
            await EnsureCompanyTypesAsync(request, current: null);

            var entity = _mapper.Map<Project>(request);
            // Whoever is signed in raised it - never an id the client sends.
            entity.CreatedByUserId = _currentUser.Id
                ?? throw new ForbiddenException("The token carries no user.");
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
                await CompanyRules.EnsureSelectableAsync(_dbContext, request.CustomerId, entity.CustomerId, "customer");
                await CompanyRules.EnsureSelectableAsync(
                    _dbContext, request.DeliveryCompanyId, entity.DeliveryCompanyId, "delivery company");
                await EnsureCompanyTypesAsync(request, entity);
                _mapper.Map(request, entity);
            }

            await _dbContext.SaveChangesAsync();

            return _mapper.Map<ProjectResponse>(entity);
        }

        /// <summary>
        /// The customer is a customer company; the goods are delivered to anyone but
        /// a transport company, which hauls them rather than receives them.
        /// </summary>
        private async Task EnsureCompanyTypesAsync(ProjectInsertRequest request, Project? current)
        {
            await CompanyRules.EnsureTypeAsync(
                _dbContext, request.CustomerId, current?.CustomerId, CompanyRules.CustomerType, mustBe: true, "customer");
            await CompanyRules.EnsureTypeAsync(
                _dbContext, request.DeliveryCompanyId, current?.DeliveryCompanyId,
                CompanyRules.TransportType, mustBe: false, "delivery company");
        }

        /// <summary>
        /// The only door <c>ProjectStatusId</c> ever changes through. Refuses a
        /// jump <see cref="ProjectStatusRules.AllowedNext"/> does not list, sets
        /// <c>ProductionStartDate</c> the moment a project first reaches "In
        /// production", and writes the move to the status history.
        /// </summary>
        public async Task<ProjectResponse> ChangeStatusAsync(int id, int newStatusId, string? reason, int changedByUserId)
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

            var storedReason = StatusChangeRules.ReasonFor(
                newStatus.Name == ProjectStatusRules.Rejected, reason, "project");

            var fromStatusName = entity.ProjectStatus.Name;
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
                Reason = storedReason,
            });

            await NotifyStatusChangeAsync(entity, fromStatusName, newStatus.Name, storedReason, changedByUserId);

            // One save: the move, its history row and the notifications about it.
            await _dbContext.SaveChangesAsync();

            return _mapper.Map<ProjectResponse>(entity);
        }

        /// <summary>
        /// A project is never deleted: it ends as "Delivered" or "Rejected", and its
        /// hours, cargo and status history stay. <c>ProjectController</c> does not
        /// route a DELETE at all; this is the same rule for any other caller.
        /// </summary>
        public override Task DeleteAsync(int id) =>
            throw new ClientException(
                $"A project is never deleted - change its status to \"{ProjectStatusRules.Rejected}\" instead.");

        /// <summary>Admins and project managers hear about every move, a rejection with its reason.</summary>
        private async Task NotifyStatusChangeAsync(
            Project project, string from, string to, string? reason, int changedByUserId)
        {
            var actor = await _dbContext.Users
                .Where(x => x.Id == changedByUserId)
                .Select(x => (x.Name + " " + x.Surname).Trim())
                .FirstOrDefaultAsync() ?? "Someone";

            var rejected = to == ProjectStatusRules.Rejected;
            var message = $"{actor} moved {project.Code} {project.Name} from \"{from}\" to \"{to}\"."
                + (rejected ? $" Reason: {reason}" : string.Empty);

            await _notifications.StageForRolesAsync(
                NotificationTypeRules.ProjectStatus,
                rejected ? "Project rejected" : "Project status changed",
                message,
                changedByUserId,
                Roles.Admin, Roles.ProjectManager);
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
                    Reason = x.Reason,
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
