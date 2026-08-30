using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.SearchObjects;
using pwm.Services;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Adds insert, update and delete on top of the read endpoints. Reading is open to every
    /// signed-in user; writing is office work, so controllers whose data the shop floor also
    /// writes (work logs) widen the roles on the actions they override.
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
        [Authorization(Roles.Administrator, Roles.Manager)]
        public virtual async Task<TResponse> Insert([FromBody] TInsertRequest request)
        {
            return await _crudService.InsertAsync(request);
        }

        [HttpPut("{id}")]
        [Authorization(Roles.Administrator, Roles.Manager)]
        public virtual async Task<TResponse> Update(int id, [FromBody] TUpdateRequest request)
        {
            return await _crudService.UpdateAsync(id, request);
        }

        [HttpDelete("{id}")]
        [Authorization(Roles.Administrator, Roles.Manager)]
        public virtual async Task<IActionResult> Delete(int id)
        {
            await _crudService.DeleteAsync(id);
            return NoContent();
        }
    }
}
