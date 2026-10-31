using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services.Interfaces
{
    /// <summary>
    /// Shifts are read-only from outside: they are worked out from their blocks of
    /// work, which are written through clocking in and out or <see cref="IWorkLogDetailService"/>.
    /// </summary>
    public interface IWorkLogService : IBaseReadService<WorkLogResponse, WorkLogSearchObject>
    {
        Task<ClockInOptionsResponse> GetClockInOptionsAsync();

        Task<ClockSessionResponse> ClockInAsync(ClockInRequest request);

        Task<ClockSessionResponse> ClockOutAsync();
    }
}
