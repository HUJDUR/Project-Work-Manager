using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace pwm.Services.Database
{
    /// <summary>
    /// One run of a report. The PDF itself is not stored - it is rebuilt from these
    /// parameters when someone downloads it again, so an old file can never disagree
    /// with the work logs it was drawn from. Who ran it and when is an
    /// <see cref="ActivityLog"/> row pointing back here, not a column.
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
    }
}
