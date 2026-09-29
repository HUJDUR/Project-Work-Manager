using Microsoft.Extensions.Caching.Memory;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;

namespace pwm.Services
{
    /// <summary>
    /// A <see cref="BaseReadService{TEntity, TResponse, TSearch}"/> for a reference table
    /// the API never writes (UserType, ProjectStatusType, ActivityLogType, ReportType) -
    /// application code matches their rows by name, so they only change through a seed
    /// or migration. Lists are served from <see cref="LookupCache{TEntity, TResponse, TSearch}"/>.
    /// </summary>
    public abstract class CachedReadService<TEntity, TResponse, TSearch>
        : BaseReadService<TEntity, TResponse, TSearch>
        where TEntity : class
        where TSearch : BaseSearchObject
    {
        private readonly IMemoryCache _cache;

        protected CachedReadService(PWMDbContext dbContext, MapsterMapper.IMapper mapper, IMemoryCache cache)
            : base(mapper, dbContext)
        {
            _cache = cache;
        }

        public override Task<PageResult<TResponse>> GetAllAsync(TSearch? search = null) =>
            LookupCache<TEntity, TResponse, TSearch>.GetOrLoadAsync(_cache, search, () => base.GetAllAsync(search));
    }
}
