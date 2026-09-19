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
    public class UserTypeService
        : BaseCRUDService<UserType, UserTypeResponse, UserTypeSearchObject, UserTypeInsertRequest, UserTypeUpdateRequest>, IUserTypeService
    {
        public UserTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<UserTypeInsertRequest> insertValidator,
            IValidator<UserTypeUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IQueryable<UserType> ApplyFilters(IQueryable<UserType> query, UserTypeSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Type))
            {
                var type = search.Type;
                query = query.Where(x => EF.Functions.Like(x.Type, $"%{type}%"));
            }

            return query;
        }
    }
}
