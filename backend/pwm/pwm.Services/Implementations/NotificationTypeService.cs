using FluentValidation;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    /// <summary>
    /// The office's notification types. A system type is found by name in code, so it
    /// stays exactly as seeded; everything written here is a type sent by hand.
    /// </summary>
    public class NotificationTypeService
        : CachedLookupService<NotificationType, NotificationTypeResponse, NotificationTypeSearchObject, NotificationTypeInsertRequest, NotificationTypeUpdateRequest>, INotificationTypeService
    {
        public NotificationTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<NotificationTypeInsertRequest> insertValidator,
            IValidator<NotificationTypeUpdateRequest> updateValidator,
            IMemoryCache cache)
            : base(dbContext, mapper, insertValidator, updateValidator, cache)
        {
        }

        public override async Task<NotificationTypeResponse> InsertAsync(NotificationTypeInsertRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);
            await EnsureNameFreeAsync(request.Name, exceptId: null);

            return await base.InsertAsync(request);
        }

        public override async Task<NotificationTypeResponse> UpdateAsync(int id, NotificationTypeUpdateRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);
            await EnsureEditableAsync(id, "renamed");
            await EnsureNameFreeAsync(request.Name, exceptId: id);

            return await base.UpdateAsync(id, request);
        }

        public override async Task DeleteAsync(int id)
        {
            await EnsureEditableAsync(id, "deleted");

            if (await _dbContext.Notifications.AnyAsync(x => x.NotificationTypeId == id))
            {
                throw new ClientException("Notifications of this type have already been sent, so it cannot be deleted.");
            }

            await base.DeleteAsync(id);
        }

        protected override NotificationType MapInsertRequestToEntity(NotificationTypeInsertRequest request) =>
            new() { Name = request.Name.Trim(), IsSystem = false };

        protected override void MapUpdateRequestToEntity(NotificationTypeUpdateRequest request, NotificationType entity) =>
            entity.Name = request.Name.Trim();

        private async Task EnsureEditableAsync(int id, string what)
        {
            var type = await _dbContext.NotificationTypes.FindAsync(id)
                ?? throw new NotFoundException($"NotificationType with id {id} not found.");

            if (type.IsSystem)
            {
                throw new ClientException($"\"{type.Name}\" is raised by the system, so it cannot be {what}.");
            }
        }

        // The unique index on Name would otherwise surface as a bare 500.
        private async Task EnsureNameFreeAsync(string? name, int? exceptId)
        {
            var trimmed = name?.Trim() ?? string.Empty;

            if (await _dbContext.NotificationTypes.AnyAsync(x => x.Id != exceptId && x.Name == trimmed))
            {
                throw new ClientException($"There already is a \"{trimmed}\" notification type.");
            }
        }

        protected override IQueryable<NotificationType> ApplyFilters(IQueryable<NotificationType> query, NotificationTypeSearchObject? search)
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

            if (search.IsSystem.HasValue)
            {
                query = query.Where(x => x.IsSystem == search.IsSystem.Value);
            }

            return query;
        }
    }
}
