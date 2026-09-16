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
    public class ProjectStatusTypeService
        : BaseCRUDService<ProjectStatusType, ProjectStatusTypeResponse, ProjectStatusTypeSearchObject, ProjectStatusTypeInsertRequest, ProjectStatusTypeUpdateRequest>, IProjectStatusTypeService
    {
        public ProjectStatusTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<ProjectStatusTypeInsertRequest> insertValidator,
            IValidator<ProjectStatusTypeUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override IEnumerable<ProjectStatusType> ApplyFilters(IEnumerable<ProjectStatusType> query, ProjectStatusTypeSearchObject? search)
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
