namespace pwm.Model.Responses
{
    /// <summary>Answers a report request the instant it is queued - never the PDF itself.</summary>
    public class ReportQueuedResponse
    {
        public int GeneratedReportId { get; set; }

        public string Status { get; set; } = string.Empty;
    }
}
