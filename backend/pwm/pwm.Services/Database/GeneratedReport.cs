using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using pwm.Model.Enums;

namespace pwm.Services.Database
{
    /// <summary>
    /// One run of a report. The PDF itself is not stored - it is rebuilt from these
    /// parameters when someone downloads it again, so an old file can never disagree
    /// with the work logs it was drawn from.
    /// </summary>
    public class GeneratedReport
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public ReportType Type { get; set; }

        /// <summary>The request that produced it, as JSON - period, worker, project.</summary>
        [Required]
        [MaxLength(1000)]
        public string Parameters { get; set; } = string.Empty;

        [Required]
        public DateTime GeneratedAt { get; set; } = DateTime.UtcNow;

        public int GeneratedById { get; set; }

        [ForeignKey(nameof(GeneratedById))]
        [Required]
        public User GeneratedBy { get; set; } = null!;
    }
}
