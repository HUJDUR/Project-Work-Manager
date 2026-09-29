using Microsoft.EntityFrameworkCore;
using FluentValidation;
using MapsterMapper;
using pwm.Model.Access;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Business;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class TruckLoadService
        : BaseCRUDService<TruckLoad, TruckLoadResponse, TruckLoadSearchObject, TruckLoadInsertRequest, TruckLoadUpdateRequest>, ITruckLoadService
    {
        private readonly ICurrentUser _currentUser;

        public TruckLoadService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<TruckLoadInsertRequest> insertValidator,
            IValidator<TruckLoadUpdateRequest> updateValidator,
            ICurrentUser currentUser)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _currentUser = currentUser;
        }

        /// <summary>Every transport starts life "Ordered", never whatever the
        /// caller sent - the request cannot even express a status any more (see
        /// <see cref="TruckLoadInsertRequest"/>), and nothing is invoiced before
        /// the load exists. The creation itself is the first row of the status
        /// history.</summary>
        public override async Task<TruckLoadResponse> InsertAsync(TruckLoadInsertRequest request)
        {
            await _insertValidator.ValidateAndThrowAsync(request);

            var orderedStatus = await _dbContext.TruckLoadStatusTypes
                    .FirstOrDefaultAsync(x => x.Name == TruckLoadStatusRules.Ordered)
                ?? throw new InvalidOperationException(
                    $"The \"{TruckLoadStatusRules.Ordered}\" truck load status is missing - reseed the lookup tables.");

            var entity = _mapper.Map<TruckLoad>(request);
            entity.TruckLoadStatusId = orderedStatus.Id;
            entity.Price = null;

            _dbContext.TruckLoads.Add(entity);

            // Through the navigation, not the id: the load has none yet, and EF
            // fixes the key up itself, so both rows commit in one SaveChangesAsync.
            _dbContext.TruckLoadStatusChanges.Add(new TruckLoadStatusChange
            {
                TruckLoad = entity,
                FromStatusId = null,
                ToStatusId = orderedStatus.Id,
                ChangedByUserId = CurrentUserIdOrThrow(),
                ChangedAt = DateTime.UtcNow,
            });
            await _dbContext.SaveChangesAsync();

            return _mapper.Map<TruckLoadResponse>(entity);
        }

        /// <summary>
        /// <c>TruckLoadStatusId</c> is never touched here - the request cannot
        /// express it any more, so nothing needs to guard against it. What is
        /// guarded: a load only takes its full set of fields while Ordered; once
        /// Delivered, only Notes and Price change; Finished or Rejected, only Notes.
        /// </summary>
        public override async Task<TruckLoadResponse> UpdateAsync(int id, TruckLoadUpdateRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);
            await _updateValidator.ValidateAndThrowAsync(request);

            var entity = await _dbContext.TruckLoads
                    .Include(x => x.TruckLoadStatus)
                    .FirstOrDefaultAsync(x => x.Id == id)
                ?? throw new NotFoundException($"TruckLoad with id {id} not found.");

            var status = entity.TruckLoadStatus.Name;

            if (TruckLoadStatusRules.CanEditGeneralFields(status))
            {
                _mapper.Map(request, entity);
                // Never settable while still Ordered - nothing to invoice yet.
                entity.Price = null;
            }
            else
            {
                if (TruckLoadStatusRules.CanEditPrice(status))
                {
                    entity.Price = request.Price;
                }

                if (TruckLoadStatusRules.CanEditNotes(status))
                {
                    entity.Note = request.Note;
                }
            }

            await _dbContext.SaveChangesAsync();

            return _mapper.Map<TruckLoadResponse>(entity);
        }

        /// <summary>
        /// The only door <c>TruckLoadStatusId</c> ever changes through. Refuses a
        /// jump <see cref="TruckLoadStatusRules.AllowedNext"/> does not list,
        /// requires at least one cargo line before "Delivered" and an invoice
        /// amount before "Finished" (which is also the only place <c>Price</c> is
        /// ever set for good), and writes the move to the status history.
        /// </summary>
        public async Task<TruckLoadResponse> ChangeStatusAsync(int id, int newStatusId, decimal? price)
        {
            var entity = await _dbContext.TruckLoads
                    .Include(x => x.TruckLoadStatus)
                    .FirstOrDefaultAsync(x => x.Id == id)
                ?? throw new NotFoundException($"TruckLoad with id {id} not found.");

            var newStatus = await _dbContext.TruckLoadStatusTypes.FindAsync(newStatusId)
                ?? throw new ClientException("That status does not exist.");

            var allowed = TruckLoadStatusRules.AllowedNext(entity.TruckLoadStatus.Name);
            if (!allowed.Contains(newStatus.Name))
            {
                throw new ClientException(
                    $"A transport cannot move from \"{entity.TruckLoadStatus.Name}\" to \"{newStatus.Name}\".");
            }

            if (newStatus.Name == TruckLoadStatusRules.Delivered)
            {
                var hasCargo = await _dbContext.TruckLoadDetails.AnyAsync(x => x.TruckLoadId == id);
                if (!hasCargo)
                {
                    throw new ClientException(
                        "Add at least one line of cargo before marking a transport delivered.");
                }
            }

            if (newStatus.Name == TruckLoadStatusRules.Finished)
            {
                if (price is null || price <= 0)
                {
                    throw new ClientException("Enter the invoice amount to finish this transport.");
                }

                entity.Price = price;
            }

            var fromStatusId = entity.TruckLoadStatusId;
            entity.TruckLoadStatusId = newStatus.Id;

            _dbContext.TruckLoadStatusChanges.Add(new TruckLoadStatusChange
            {
                TruckLoadId = id,
                FromStatusId = fromStatusId,
                ToStatusId = newStatus.Id,
                ChangedByUserId = CurrentUserIdOrThrow(),
                ChangedAt = DateTime.UtcNow,
            });

            await _dbContext.SaveChangesAsync();

            return _mapper.Map<TruckLoadResponse>(entity);
        }

        /// <summary>Newest first - the story of how a transport got to where it is.</summary>
        public async Task<List<TruckLoadStatusChangeResponse>> GetStatusHistoryAsync(int truckLoadId)
        {
            return await _dbContext.TruckLoadStatusChanges
                .Where(x => x.TruckLoadId == truckLoadId)
                .OrderByDescending(x => x.ChangedAt)
                .Select(x => new TruckLoadStatusChangeResponse
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

        private int CurrentUserIdOrThrow() =>
            _currentUser.Id ?? throw new ForbiddenException("The token carries no user.");

        protected override Task<IQueryable<TruckLoad>> IncludeRelatedEntitiesAsync(
            TruckLoadSearchObject? search, IQueryable<TruckLoad> query)
        {
            // Search matches the carrier's name too, so that navigation has to be loaded.
            return Task.FromResult<IQueryable<TruckLoad>>(query.Include(x => x.TransportCompany));
        }

        protected override IQueryable<TruckLoad> ApplyFilters(IQueryable<TruckLoad> query, TruckLoadSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Search))
            {
                var needle = search.Search;
                query = query.Where(x =>
                    EF.Functions.Like(x.DriverName, $"%{needle}%")
                    || EF.Functions.Like(x.DriverSurname, $"%{needle}%")
                    || EF.Functions.Like(x.VehicleRegistration, $"%{needle}%")
                    || (x.TransportCompany != null && EF.Functions.Like(x.TransportCompany.Name, $"%{needle}%")));
            }

            if (search.TruckLoadStatusId.HasValue)
            {
                query = query.Where(x => x.TruckLoadStatusId == search.TruckLoadStatusId.Value);
            }

            if (search.TransportCompanyId.HasValue)
            {
                query = query.Where(x => x.TransportCompanyId == search.TransportCompanyId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.VehicleRegistration))
            {
                var vehicleRegistration = search.VehicleRegistration;
                query = query.Where(x => EF.Functions.Like(x.VehicleRegistration, $"%{vehicleRegistration}%"));
            }

            if (search.DateFrom.HasValue)
            {
                query = query.Where(x => x.LoadDate >= search.DateFrom.Value);
            }

            if (search.DateTo.HasValue)
            {
                query = query.Where(x => x.LoadDate <= search.DateTo.Value);
            }

            return query;
        }
    }
}
