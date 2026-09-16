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
    public class ActivityLogTypeService
        : BaseCRUDService<ActivityLogType, ActivityLogTypeResponse, ActivityLogTypeSearchObject, ActivityLogTypeInsertRequest, ActivityLogTypeUpdateRequest>, IActivityLogTypeService
    {
        public ActivityLogTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<ActivityLogTypeInsertRequest> insertValidator,
            IValidator<ActivityLogTypeUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IEnumerable<ActivityLogType> ApplyFilters(IEnumerable<ActivityLogType> query, ActivityLogTypeSearchObject? search)
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
