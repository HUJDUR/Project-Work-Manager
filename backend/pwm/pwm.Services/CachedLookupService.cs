using FluentValidation;
using Microsoft.Extensions.Caching.Memory;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;

namespace pwm.Services
{
    /// <summary>
    /// A <see cref="BaseCRUDService{TEntity, TResponse, TSearch, TInsertRequest, TUpdateRequest}"/>
    /// for an editable reference/lookup table (City, Country, OperationType, and so on) -
    /// the ones the desktop's Administration screen manages. Lists are served from
    /// <see cref="LookupCache{TEntity, TResponse, TSearch}"/>, and every write drops it.
    /// </summary>
    public abstract class CachedLookupService<TEntity, TResponse, TSearch, TInsertRequest, TUpdateRequest>
        : BaseCRUDService<TEntity, TResponse, TSearch, TInsertRequest, TUpdateRequest>
        where TEntity : class
        where TSearch : BaseSearchObject
    {
        private readonly IMemoryCache _cache;

        protected CachedLookupService(
            PWMDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IValidator<TInsertRequest> insertValidator,
            IValidator<TUpdateRequest> updateValidator,
            IMemoryCache cache)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _cache = cache;
        }

        public override Task<PageResult<TResponse>> GetAllAsync(TSearch? search = null) =>
            LookupCache<TEntity, TResponse, TSearch>.GetOrLoadAsync(_cache, search, () => base.GetAllAsync(search));

        public override async Task<TResponse> InsertAsync(TInsertRequest request)
        {
            var result = await base.InsertAsync(request);
            LookupCache<TEntity, TResponse, TSearch>.Invalidate(_cache);
            return result;
        }

        public override async Task<TResponse> UpdateAsync(int id, TUpdateRequest request)
        {
            var result = await base.UpdateAsync(id, request);
            LookupCache<TEntity, TResponse, TSearch>.Invalidate(_cache);
            return result;
        }

        public override async Task DeleteAsync(int id)
        {
            await base.DeleteAsync(id);
            LookupCache<TEntity, TResponse, TSearch>.Invalidate(_cache);
        }
    }
}
