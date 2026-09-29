using System.Reflection;
using Microsoft.Extensions.Caching.Memory;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services
{
    /// <summary>
    /// The list cache behind every reference/lookup table's service - the small,
    /// rarely-changing tables nearly every dropdown across both frontends reads on
    /// close to every request. The coding standard calls for exactly this: data read
    /// on every request should be cached via <see cref="IMemoryCache"/> at the service
    /// level, not an instance-level dictionary on a Transient service. The services are
    /// Scoped (one instance per request), so the set of keys a write needs to drop is
    /// <c>static</c> here - one set per closed generic type - or it would start empty
    /// every time and never see what an earlier request had cached.
    /// </summary>
    internal static class LookupCache<TEntity, TResponse, TSearch>
        where TSearch : BaseSearchObject
    {
        /// <summary>
        /// How long an entry survives without a write - a safety net for a row changed
        /// straight in the database rather than through the API. The normal way a change
        /// is seen is immediate: every write drops the cache via <see cref="Invalidate"/>.
        /// </summary>
        private static readonly TimeSpan Duration = TimeSpan.FromMinutes(5);

        private static readonly HashSet<string> Keys = [];
        private static readonly object KeysLock = new();

        private static readonly string KeyPrefix = $"lookup:{typeof(TEntity).Name}:";

        public static async Task<PageResult<TResponse>> GetOrLoadAsync(
            IMemoryCache cache, TSearch? search, Func<Task<PageResult<TResponse>>> load)
        {
            var key = KeyPrefix + BuildSearchKey(search);

            if (cache.TryGetValue(key, out PageResult<TResponse>? cached) && cached is not null)
            {
                return cached;
            }

            var result = await load();

            lock (KeysLock)
            {
                Keys.Add(key);
            }

            cache.Set(key, result, Duration);

            return result;
        }

        public static void Invalidate(IMemoryCache cache)
        {
            lock (KeysLock)
            {
                foreach (var key in Keys)
                {
                    cache.Remove(key);
                }

                Keys.Clear();
            }
        }

        /// <summary>
        /// One key per distinct combination of paging/sorting/filters a caller asks for -
        /// reflection over every public property keeps this correct for whatever a derived
        /// search object (<c>CitySearchObject</c>, and so on) happens to add, without each
        /// lookup service having to hand-list its own filter fields.
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
