using pwm.Model.Requests;

namespace pwm.Services.Interfaces
{
    /// <summary>
    /// Builds the PDFs on demand and records that they were built. Nothing stores the
    /// bytes, so a report can never drift from the work logs it was drawn from.
    /// </summary>
    public interface IReportService
    {
        Task<byte[]> MonthlyWorkHoursAsync(MonthlyWorkHoursReportRequest request, int generatedById);

        Task<byte[]> TransportLoadsAsync(TransportLoadsReportRequest request, int generatedById);

        /// <summary>
        /// Rebuilds a report from the parameters it was first run with. A project
        /// manager cannot rebuild a monthly hours report - <paramref name="callerRole"/>
        /// is what lets this check that, since the download route has no report type
        /// of its own for <c>[Authorization]</c> to see.
        /// </summary>
        Task<(byte[] Content, string FileName)> RerunAsync(int generatedReportId, string? callerRole);
    }
}
