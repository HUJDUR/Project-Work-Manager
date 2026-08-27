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
    public class UserTypeService
        : BaseReadService<UserType, UserTypeResponse, UserTypeSearchObject>, IUserTypeService
    {
        public UserTypeService(PWMDbContext dbContext, IMapper mapper)
            : base(mapper, dbContext)
        {
        }

        protected override IEnumerable<UserType> ApplyFilters(IEnumerable<UserType> query, UserTypeSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Type))
            {
                var type = search.Type;
                query = query.Where(x => x.Type.Contains(type, StringComparison.OrdinalIgnoreCase));
            }

            return query;
        }
    }
}
