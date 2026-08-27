using System;
using System.Collections.Generic;
using System.Linq;
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

        protected override IEnumerable<TruckLoad> ApplyFilters(IEnumerable<TruckLoad> query, TruckLoadSearchObject? search)
        {
            if (search == null)
            {
                return query;
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
