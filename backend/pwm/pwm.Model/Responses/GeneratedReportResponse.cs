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

        /// <summary>Who ran it - read from the run's <c>ActivityLog</c> entry. Null for a run with none.</summary>
        public int? GeneratedByUserId { get; set; }

        public string? GeneratedByName { get; set; }

        /// <summary>When it was run, in UTC - from the same <c>ActivityLog</c> entry.</summary>
        public DateTime? GeneratedAt { get; set; }
    }
}
