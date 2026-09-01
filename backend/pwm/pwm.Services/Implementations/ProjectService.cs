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
    public class ProjectService
        : BaseCRUDService<Project, ProjectResponse, ProjectSearchObject, ProjectInsertRequest, ProjectUpdateRequest>, IProjectService
    {
        public ProjectService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<ProjectInsertRequest> insertValidator,
            IValidator<ProjectUpdateRequest> updateValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
        }

        protected override Task<IQueryable<Project>> IncludeRelatedEntitiesAsync(
            ProjectSearchObject? search, IQueryable<Project> query)
        {
            // Search matches the customer's name too, so that navigation has to be loaded.
            return Task.FromResult<IQueryable<Project>>(query.Include(x => x.Customer));
        }

        protected override IEnumerable<Project> ApplyFilters(IEnumerable<Project> query, ProjectSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Search))
            {
                var needle = search.Search;
                query = query.Where(x =>
                    x.Name.Contains(needle, StringComparison.OrdinalIgnoreCase)
                    || (x.Customer != null
                        && x.Customer.Name.Contains(needle, StringComparison.OrdinalIgnoreCase)));
            }

            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                var name = search.Name;
                query = query.Where(x => x.Name.Contains(name, StringComparison.OrdinalIgnoreCase));
            }

            if (search.CustomerId.HasValue)
            {
                query = query.Where(x => x.CustomerId == search.CustomerId.Value);
            }

            if (search.ProjectCategoryId.HasValue)
            {
                query = query.Where(x => x.ProjectCategoryId == search.ProjectCategoryId.Value);
            }

            if (search.ProjectStatusId.HasValue)
            {
                query = query.Where(x => x.ProjectStatusId == search.ProjectStatusId.Value);
            }

            if (search.Priority.HasValue)
            {
                query = query.Where(x => x.Priority == search.Priority.Value);
            }

            if (search.CreatedByUserId.HasValue)
            {
                query = query.Where(x => x.CreatedByUserId == search.CreatedByUserId.Value);
            }

            if (search.DeliveryCompanyId.HasValue)
            {
                query = query.Where(x => x.DeliveryCompanyId == search.DeliveryCompanyId.Value);
            }

            return query;
        }
    }
}
