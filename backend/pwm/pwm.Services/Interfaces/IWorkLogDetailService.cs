using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services.Interfaces
{
    public interface IWorkLogDetailService : IBaseCRUDService<WorkLogDetailResponse, WorkLogDetailSearchObject, WorkLogDetailInsertRequest, WorkLogDetailUpdateRequest>
    {
        /// <summary>
        /// The Work Hours screen: blocks joined to their worker, project and operation,
        /// split into regular and overtime hours, filtered and paged - newest first.
        /// </summary>
        Task<PageResult<WorkHoursEntryResponse>> GetHoursAsync(WorkHoursSearchObject search);
    }
}
