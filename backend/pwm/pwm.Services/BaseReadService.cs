using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
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
        /// </summary>
        protected abstract IEnumerable<TEntity> ApplyFilters(IEnumerable<TEntity> query, TSearch? search);

        public virtual async Task<PageResult<TResponse>> GetAllAsync(TSearch? search = null)
        {
            search ??= Activator.CreateInstance<TSearch>();
            ClampPaging(search);

            IEnumerable<TEntity> query = this._dbContext.Set<TEntity>();

            query = await IncludeRelatedEntitiesAsync(search, query.AsQueryable());
            query = ApplyFilters(query, search);

            int? totalCount = null;

            if (search.IncludeTotalCount ?? false)
            {
                totalCount = query.Count();
            }

            if (!string.IsNullOrWhiteSpace(search.SortBy))
            {
                //TODO: parametrize sortBy to prevent SQL injection
                query = query.AsQueryable().OrderBy(search.SortBy);
            }

            query = query
                .Skip((search.Page!.Value - 1) * search.PageSize!.Value)
                .Take(search.PageSize.Value);

            var list = query.Select(item => _mapper.Map<TResponse>(item)).ToList();

            var pageResult = new PageResult<TResponse>
            {
                Items = list,
                TotalCount = totalCount
            };

            return await Task.FromResult(pageResult);
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

        protected virtual async Task<IQueryable<TEntity>> IncludeRelatedEntitiesAsync(TSearch? search, IQueryable<TEntity> query = null)
        {
            // Override in derived classes to include related entities if necessary
            return query;
        }


        public virtual async Task<TResponse> GetByIdAsync(int id)
        {
            var entity = this._dbContext.Set<TEntity>().Find(id);
            if (entity == null)
            {
                throw new KeyNotFoundException($"{typeof(TEntity).Name} with id {id} not found.");
            }

            return await Task.FromResult(_mapper.Map<TResponse>(entity));
        }
    }
}
