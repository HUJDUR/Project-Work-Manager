using pwm.Model.Requests;
using pwm.Model.Responses;

namespace pwm.Services.Interfaces
{
    /// <summary>
    /// Queues a report and hands back its id immediately; <c>pwm.Worker</c> is what
    /// actually renders the PDF, off RabbitMQ. Nothing here builds one synchronously
    /// any more - see <c>pwm.Services.Reporting.ReportBuilder</c> for that.
    /// </summary>
    public interface IReportService
    {
        Task<ReportQueuedResponse> MonthlyWorkHoursAsync(MonthlyWorkHoursReportRequest request, int generatedById);

        Task<ReportQueuedResponse> TransportLoadsAsync(TransportLoadsReportRequest request, int generatedById);

        /// <summary>
        /// A project manager cannot see a monthly hours report - <paramref name="callerRole"/>
        /// is what lets this check that, since the route has no report type of its
        /// own for <c>[Authorization]</c> to see.
        /// </summary>
        Task<ReportStatusResponse> GetStatusAsync(int generatedReportId, string? callerRole);

        /// <summary>Serves the PDF the worker already rendered. Throws if it is not ready yet.</summary>
        Task<(byte[] Content, string FileName)> DownloadAsync(int generatedReportId, string? callerRole);
    }
}
