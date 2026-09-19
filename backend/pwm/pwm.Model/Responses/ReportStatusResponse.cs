namespace pwm.Model.Responses
{
    /// <summary>What the Reports screen polls while a PDF is being built.</summary>
    public class ReportStatusResponse
    {
        public int Id { get; set; }

        public string Status { get; set; } = string.Empty;

        /// <summary>Set only when <see cref="Status"/> is "Failed".</summary>
        public string? ErrorMessage { get; set; }
    }
}
