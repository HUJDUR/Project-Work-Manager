using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using pwm.Model.Enums;

namespace pwm.Services.Database
{
    /// <summary>
    /// One run of a report. The API only creates the row and hands it to RabbitMQ;
    /// <c>pwm.Worker</c> is the only thing that renders the PDF, stores it in
    /// <see cref="Content"/>, and moves <see cref="Status"/> on from <see cref="ReportStatus.Pending"/>.
    /// Who ran it and when is an <see cref="ActivityLog"/> row pointing back here, not a column.
    /// </summary>
    public class GeneratedReport
    {
        [Key]
        public int Id { get; set; }

        public int ReportTypeId { get; set; }

        [ForeignKey(nameof(ReportTypeId))]
        [Required]
        public ReportType ReportType { get; set; } = null!;

        /// <summary>The request that produced it, as JSON - period, worker, project.</summary>
        [Required]
        [MaxLength(1000)]
        public string Parameters { get; set; } = string.Empty;

        public ReportStatus Status { get; set; } = ReportStatus.Pending;

        /// <summary>The rendered PDF, once the worker finishes. Null until then.</summary>
        public byte[]? Content { get; set; }

        /// <summary>Set only when <see cref="Status"/> is <see cref="ReportStatus.Failed"/>.</summary>
        [MaxLength(1000)]
        public string? ErrorMessage { get; set; }
    }
}
