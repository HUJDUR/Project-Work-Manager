using System.Threading.Tasks;
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

        /// <summary>Rebuilds a report from the parameters it was first run with.</summary>
        Task<(byte[] Content, string FileName)> RerunAsync(int generatedReportId);

        /// <summary>Which report a past run was, so a caller can check it against their role.</summary>
        Task<int> TypeOfAsync(int generatedReportId);
    }
}
