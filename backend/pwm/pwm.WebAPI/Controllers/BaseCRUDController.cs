using Microsoft.AspNetCore.Mvc;
using pwm.Model.SearchObjects;
using pwm.Services;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Adds insert, update and delete on top of the read endpoints.
    /// </summary>
    [ApiController]
    [Route("[controller]")]
    public abstract class BaseCRUDController<TResponse, TSearch, TInsertRequest, TUpdateRequest>
        : BaseReadController<TResponse, TSearch>
        where TSearch : BaseSearchObject, new()
    {
        protected readonly IBaseCRUDService<TResponse, TSearch, TInsertRequest, TUpdateRequest> _crudService;

        protected BaseCRUDController(IBaseCRUDService<TResponse, TSearch, TInsertRequest, TUpdateRequest> service)
            : base(service)
        {
            _crudService = service;
        }

        [HttpPost]
        public virtual async Task<TResponse> Insert([FromBody] TInsertRequest request)
        {
            return await _crudService.InsertAsync(request);
        }

        [HttpPut("{id}")]
        public virtual async Task<TResponse> Update(int id, [FromBody] TUpdateRequest request)
        {
            return await _crudService.UpdateAsync(id, request);
        }

        [HttpDelete("{id}")]
        public virtual async Task<IActionResult> Delete(int id)
        {
            await _crudService.DeleteAsync(id);
            return NoContent();
        }
    }
}
