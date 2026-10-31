using FluentValidation;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Business;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class CompanyTypeService
        : CachedLookupService<CompanyType, CompanyTypeResponse, CompanyTypeSearchObject, CompanyTypeInsertRequest, CompanyTypeUpdateRequest>, ICompanyTypeService
    {
        public CompanyTypeService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<CompanyTypeInsertRequest> insertValidator,
            IValidator<CompanyTypeUpdateRequest> updateValidator,
            IMemoryCache cache)
            : base(dbContext, mapper, insertValidator, updateValidator, cache)
        {
        }

        /// <summary>
        /// The customer and transport types are what <see cref="CompanyRules"/> tells
        /// a customer from a carrier by, so their names stay as they are.
        /// </summary>
        public override async Task<CompanyTypeResponse> UpdateAsync(int id, CompanyTypeUpdateRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);

            var current = await _dbContext.CompanyTypes.FindAsync(id)
                ?? throw new NotFoundException($"CompanyType with id {id} not found.");

            if (IsProtected(current.Name) && !string.Equals(current.Name, request.Name?.Trim(), StringComparison.Ordinal))
            {
                throw new ClientException(
                    $"\"{current.Name}\" is how customers and carriers are told apart, so it cannot be renamed.");
            }

            return await base.UpdateAsync(id, request);
        }

        public override async Task DeleteAsync(int id)
        {
            var current = await _dbContext.CompanyTypes.FindAsync(id)
                ?? throw new NotFoundException($"CompanyType with id {id} not found.");

            if (IsProtected(current.Name))
            {
                throw new ClientException(
                    $"\"{current.Name}\" is how customers and carriers are told apart, so it cannot be deleted.");
            }

            await base.DeleteAsync(id);
        }

        private static bool IsProtected(string name) =>
            CompanyRules.ProtectedTypes.Contains(name, StringComparer.OrdinalIgnoreCase);

        protected override IQueryable<CompanyType> ApplyFilters(IQueryable<CompanyType> query, CompanyTypeSearchObject? search)
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
