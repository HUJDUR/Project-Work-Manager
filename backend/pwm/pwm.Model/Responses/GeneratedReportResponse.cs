namespace pwm.Model.Responses
{
    public class GeneratedReportResponse
    {
        public int Id { get; set; }

        public int ReportTypeId { get; set; }

        public string Parameters { get; set; } = string.Empty;

        public string Status { get; set; } = string.Empty;

        /// <summary>Set only when <see cref="Status"/> is "Failed".</summary>
        public string? ErrorMessage { get; set; }
    }
}
