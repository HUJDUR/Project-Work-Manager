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
    public class TruckLoadStatusTypeService
        : BaseCRUDService<TruckLoadStatusType, TruckLoadStatusTypeResponse, TruckLoadStatusTypeSearchObject, TruckLoadStatusTypeInsertRequest, TruckLoadStatusTypeUpdateRequest>, ITruckLoadStatusTypeService
    {
        public TruckLoadStatusTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<TruckLoadStatusTypeInsertRequest> insertValidator,
            IValidator<TruckLoadStatusTypeUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IQueryable<TruckLoadStatusType> ApplyFilters(IQueryable<TruckLoadStatusType> query, TruckLoadStatusTypeSearchObject? search)
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
