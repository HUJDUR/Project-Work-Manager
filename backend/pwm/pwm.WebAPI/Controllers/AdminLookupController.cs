using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.SearchObjects;
using pwm.Services;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Base for the seven editable reference-data controllers behind the desktop's Administration
    /// screen. Reading stays open to every signed-in user (<see cref="BaseReadController{TResponse, TSearch}"/>);
    /// writing is narrowed here, once, from <see cref="BaseCRUDController{TResponse, TSearch, TInsertRequest, TUpdateRequest}"/>'s
    /// wider office roles down to the one role the Administration screen is open to.
    /// </summary>
    public abstract class AdminLookupController<TResponse, TSearch, TInsertRequest, TUpdateRequest>
        : BaseCRUDController<TResponse, TSearch, TInsertRequest, TUpdateRequest>
        where TSearch : BaseSearchObject, new()
    {
        protected AdminLookupController(IBaseCRUDService<TResponse, TSearch, TInsertRequest, TUpdateRequest> service)
            : base(service)
        {
        }

        [HttpPost]
        [Authorization(Roles.Admin)]
        public override Task<TResponse> Insert([FromBody] TInsertRequest request)
            => base.Insert(request);

        [HttpPut("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<TResponse> Update(int id, [FromBody] TUpdateRequest request)
            => base.Update(id, request);

        [HttpDelete("{id}")]
        [Authorization(Roles.Admin)]
        public override Task<IActionResult> Delete(int id)
            => base.Delete(id);
    }
}
