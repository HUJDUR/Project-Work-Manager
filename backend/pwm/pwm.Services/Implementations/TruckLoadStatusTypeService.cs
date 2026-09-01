using System;
using System.Collections.Generic;
using System.Linq;
using MapsterMapper;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class TruckLoadStatusTypeService
        : BaseReadService<TruckLoadStatusType, TruckLoadStatusTypeResponse, TruckLoadStatusTypeSearchObject>, ITruckLoadStatusTypeService
    {
        public TruckLoadStatusTypeService(PWMDbContext dbContext, IMapper mapper)
            : base(mapper, dbContext)
        {
        }

        protected override IEnumerable<TruckLoadStatusType> ApplyFilters(IEnumerable<TruckLoadStatusType> query, TruckLoadStatusTypeSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                var name = search.Name;
                query = query.Where(x => x.Name.Contains(name, StringComparison.OrdinalIgnoreCase));
            }

            return query;
        }
    }
}
