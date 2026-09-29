using pwm.Model.Responses;

namespace pwm.Services.Interfaces
{
    public interface IDashboardService
    {
        /// <param name="includeActivity">Whether the recent activity list is filled - Admin only.</param>
        Task<DashboardResponse> GetAsync(bool includeActivity);
    }
}
