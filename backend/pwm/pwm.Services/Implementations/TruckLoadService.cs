using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using FluentValidation;
using MapsterMapper;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class TruckLoadService
        : BaseCRUDService<TruckLoad, TruckLoadResponse, TruckLoadSearchObject, TruckLoadInsertRequest, TruckLoadUpdateRequest>, ITruckLoadService
    {
        public TruckLoadService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<TruckLoadInsertRequest> insertValidator,
            IValidator<TruckLoadUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override Task<IQueryable<TruckLoad>> IncludeRelatedEntitiesAsync(
            TruckLoadSearchObject? search, IQueryable<TruckLoad> query)
        {
            // Search matches the carrier's name too, so that navigation has to be loaded.
            return Task.FromResult<IQueryable<TruckLoad>>(query.Include(x => x.TransportCompany));
        }

        protected override IEnumerable<TruckLoad> ApplyFilters(IEnumerable<TruckLoad> query, TruckLoadSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Search))
            {
                var needle = search.Search;
                query = query.Where(x =>
                    x.DriverName.Contains(needle, StringComparison.OrdinalIgnoreCase)
                    || x.DriverSurname.Contains(needle, StringComparison.OrdinalIgnoreCase)
                    || x.VehicleRegistration.Contains(needle, StringComparison.OrdinalIgnoreCase)
                    || (x.TransportCompany != null
                        && x.TransportCompany.Name.Contains(needle, StringComparison.OrdinalIgnoreCase)));
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
                query = query.Where(x => x.VehicleRegistration.Contains(vehicleRegistration, StringComparison.OrdinalIgnoreCase));
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
