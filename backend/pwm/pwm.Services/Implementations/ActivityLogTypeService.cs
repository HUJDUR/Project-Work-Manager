using FluentValidation;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
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

        protected override IQueryable<ActivityLogType> ApplyFilters(IQueryable<ActivityLogType> query, ActivityLogTypeSearchObject? search)
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

            return query;
        }
    }
}
