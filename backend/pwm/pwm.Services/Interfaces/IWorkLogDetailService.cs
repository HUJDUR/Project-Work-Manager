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
        Task<WorkHoursPageResponse> GetHoursAsync(WorkHoursSearchObject search);

        Task<MyWorkDaysResponse> GetMyDaysAsync(MyWorkDaysSearchObject search);

        /// <summary>Who changed one block of work, when, and from what to what - newest first.</summary>
        Task<List<WorkHoursChangeResponse>> GetHistoryAsync(int workLogDetailId);
    }
}
