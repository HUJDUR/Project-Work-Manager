using Microsoft.AspNetCore.Mvc;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Read-only endpoints shared by every controller: paged list and get by id.
    /// </summary>
    [ApiController]
    [Route("[controller]")]
    public abstract class BaseReadController<TResponse, TSearch> : ControllerBase
        where TSearch : BaseSearchObject, new()
    {
        protected readonly IBaseReadService<TResponse, TSearch> _service;

        protected BaseReadController(IBaseReadService<TResponse, TSearch> service)
        {
            _service = service;
        }

        // The parameter is not called "search": a query key matching the name of a complex
        // parameter makes MVC try to bind the whole object from that one value, which would
        // silently swallow the search objects' own ?search= filter.
        [HttpGet]
        public virtual async Task<PageResult<TResponse>> GetAll([FromQuery] TSearch? searchObject)
        {
            return await _service.GetAllAsync(searchObject ?? new TSearch());
        }

        [HttpGet("{id}")]
        public virtual async Task<TResponse> GetById(int id)
        {
            return await _service.GetByIdAsync(id);
        }
    }
}
