using pwm.Model.Exceptions;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using Microsoft.EntityFrameworkCore;
using System.Reflection;
using System.Linq.Dynamic.Core;

namespace pwm.Services
{
    public abstract class BaseReadService<TEntity, TResponse, TSearch> : IBaseReadService<TResponse, TSearch>
        where TEntity : class
        where TSearch : BaseSearchObject
    {
        protected readonly MapsterMapper.IMapper _mapper;
        protected readonly PWMDbContext _dbContext;

        protected BaseReadService(MapsterMapper.IMapper mapper, PWMDbContext dbContext)
        {
            _mapper = mapper;
            _dbContext = dbContext;
        }


        /// <summary>
        /// Applies search filters to the query. Override in derived classes to implement specific filtering logic.
        /// Must stay an <see cref="IQueryable{T}"/> all the way through - EF translates it to SQL - so filters
        /// belong in a Where clause here, never a LINQ-to-objects filter over an already-materialised list.
        /// </summary>
        protected abstract IQueryable<TEntity> ApplyFilters(IQueryable<TEntity> query, TSearch? search);

        public virtual async Task<PageResult<TResponse>> GetAllAsync(TSearch? search = null)
        {
            search ??= Activator.CreateInstance<TSearch>();
            ClampPaging(search);

            IQueryable<TEntity> query = this._dbContext.Set<TEntity>();

            query = await IncludeRelatedEntitiesAsync(search, query);
            query = ApplyFilters(query, search);

            int? totalCount = null;

            if (search.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync();
            }

            if (!string.IsNullOrWhiteSpace(search.SortBy))
            {
                query = query.OrderBy(SafeSortBy(search.SortBy));
            }

            query = query
                .Skip((search.Page!.Value - 1) * search.PageSize!.Value)
                .Take(search.PageSize.Value);

            var list = await query
                .Select(item => _mapper.Map<TResponse>(item))
                .ToListAsync();

            return new PageResult<TResponse>
            {
                Items = list,
                TotalCount = totalCount
            };
        }

        /// <summary>
        /// Dynamic LINQ's <c>OrderBy(string)</c> takes an expression, not just a property
        /// name, so an unchecked <see cref="BaseSearchObject.SortBy"/> is a SQL/expression
        /// injection vector straight from the query string. Only a real, public property
        /// of <typeparamref name="TEntity"/> (optionally followed by "asc"/"desc") is let through.
        /// </summary>
        private static string SafeSortBy(string sortBy)
        {
            var propertyName = sortBy.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? sortBy;

            var property = typeof(TEntity)
                .GetProperties(BindingFlags.Public | BindingFlags.Instance)
                .FirstOrDefault(p => string.Equals(p.Name, propertyName, StringComparison.OrdinalIgnoreCase));

            if (property == null)
            {
                throw new ClientException($"Cannot sort {typeof(TEntity).Name} by \"{propertyName}\".");
            }

            var direction = sortBy.Contains("desc", StringComparison.OrdinalIgnoreCase) ? "desc" : "asc";
            return $"{property.Name} {direction}";
        }

        /// <summary>
        /// Keeps every list endpoint inside <see cref="BaseSearchObject.MaxPageSize"/>: a page
        /// is never bigger than the ceiling, and never smaller than one row.
        /// </summary>
        private static void ClampPaging(TSearch search)
        {
            search.Page = Math.Max(search.Page ?? 1, 1);

            var pageSize = search.PageSize ?? BaseSearchObject.DefaultPageSize;
            search.PageSize = Math.Clamp(pageSize, 1, BaseSearchObject.MaxPageSize);
        }

        // Override in derived classes to include related entities if necessary.
        protected virtual Task<IQueryable<TEntity>> IncludeRelatedEntitiesAsync(TSearch? search, IQueryable<TEntity> query)
        {
            return Task.FromResult(query);
        }

        public virtual async Task<TResponse> GetByIdAsync(int id)
        {
            var entity = await this._dbContext.Set<TEntity>().FindAsync(id);
            if (entity == null)
            {
                throw new NotFoundException($"{typeof(TEntity).Name} with id {id} not found.");
            }

            return _mapper.Map<TResponse>(entity);
        }
    }
}
