using System.Reflection;
using FluentValidation;
using Microsoft.Extensions.Caching.Memory;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;

namespace pwm.Services
{
    /// <summary>
    /// A <see cref="BaseCRUDService{TEntity, TResponse, TSearch, TInsertRequest, TUpdateRequest}"/>
    /// for a small, rarely-changing reference/lookup table (City, Country, OperationType,
    /// and so on) - the ones the desktop's Administration screen manages, and that nearly
    /// every dropdown across both frontends reads on close to every request. The coding
    /// standard calls for exactly this: data read on every request should be cached via
    /// <see cref="IMemoryCache"/> at the service level, not an instance-level dictionary on
    /// a Transient service - which is also why the set of keys a write needs to drop is
    /// kept in a <c>static</c> field: this service is registered Scoped (one instance per
    /// request), so an instance-level set would start empty every time and never see what
    /// an earlier request had cached. <see cref="IMemoryCache"/> itself is a singleton
    /// (see <c>AddMemoryCache</c> in <c>ServiceRegistration</c>), so the cached data is
    /// already shared across requests regardless.
    /// </summary>
    public abstract class CachedLookupService<TEntity, TResponse, TSearch, TInsertRequest, TUpdateRequest>
        : BaseCRUDService<TEntity, TResponse, TSearch, TInsertRequest, TUpdateRequest>
        where TEntity : class
        where TSearch : BaseSearchObject
    {
        private readonly IMemoryCache _cache;

        // One set per closed generic type - CachedLookupService<City, ...> and
        // CachedLookupService<Country, ...> each get their own - rather than per
        // instance, for the Scoped-lifetime reason in the class doc above.
        private static readonly HashSet<string> _cacheKeys = [];
        private static readonly object _cacheKeysLock = new();

        private static readonly string _keyPrefix = $"lookup:{typeof(TEntity).Name}:";

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

        /// <summary>
        /// How long an entry survives without a write - a safety net for a row changed
        /// straight in the database rather than through the API. The normal way a change
        /// here is seen is immediate: any write below drops the cache itself.
        /// </summary>
        protected virtual TimeSpan CacheDuration => TimeSpan.FromMinutes(5);

        public override async Task<PageResult<TResponse>> GetAllAsync(TSearch? search = null)
        {
            var key = _keyPrefix + BuildSearchKey(search);

            if (_cache.TryGetValue(key, out PageResult<TResponse>? cached) && cached is not null)
            {
                return cached;
            }

            var result = await base.GetAllAsync(search);

            lock (_cacheKeysLock)
            {
                _cacheKeys.Add(key);
            }

            _cache.Set(key, result, CacheDuration);

            return result;
        }

        public override async Task<TResponse> InsertAsync(TInsertRequest request)
        {
            var result = await base.InsertAsync(request);
            InvalidateCache();
            return result;
        }

        public override async Task<TResponse> UpdateAsync(int id, TUpdateRequest request)
        {
            var result = await base.UpdateAsync(id, request);
            InvalidateCache();
            return result;
        }

        public override async Task DeleteAsync(int id)
        {
            await base.DeleteAsync(id);
            InvalidateCache();
        }

        private void InvalidateCache()
        {
            lock (_cacheKeysLock)
            {
                foreach (var key in _cacheKeys)
                {
                    _cache.Remove(key);
                }

                _cacheKeys.Clear();
            }
        }

        /// <summary>
        /// One key per distinct combination of paging/sorting/filters a caller asks for -
        /// reflection over every public property keeps this correct for whatever a derived
        /// search object (<c>CitySearchObject</c>, and so on) happens to add, without each
        /// of the ten lookup services having to hand-list its own filter fields.
        /// </summary>
        private static string BuildSearchKey(TSearch? search)
        {
            if (search is null)
            {
                return "(none)";
            }

            var parts = typeof(TSearch)
                .GetProperties(BindingFlags.Public | BindingFlags.Instance)
                .OrderBy(p => p.Name, StringComparer.Ordinal)
                .Select(p => $"{p.Name}={p.GetValue(search) ?? "(null)"}");

            return string.Join('&', parts);
        }
    }
}
