using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services.Interfaces
{
    public interface IMonthlyHourReportService : IBaseReadService<MonthlyHourReportResponse, MonthlyHourReportSearchObject>
    {
        Task<MonthlyHourReportOverviewResponse> GetOverviewAsync(int id);
    }
}
