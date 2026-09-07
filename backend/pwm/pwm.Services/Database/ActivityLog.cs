using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace pwm.Services.Database
{
    public class ActivityLog
    {
        [Key]
        public int Id { get; set; }

        public int UserId { get; set; }

        [ForeignKey(nameof(UserId))]
        [Required]
        public User User { get; set; } = null!;

        public int ActivityLogTypeId { get; set; }

        [ForeignKey(nameof(ActivityLogTypeId))]
        [Required]
        public ActivityLogType ActivityLogType { get; set; } = null!;

        /// <summary>Set only on a "Generated report" entry - this table is what records who ran it and when.</summary>
        public int? GeneratedReportId { get; set; }

        [ForeignKey(nameof(GeneratedReportId))]
        public GeneratedReport? GeneratedReport { get; set; }

        [Required]
        public DateTime Date { get; set; } = DateTime.UtcNow;
    }
}
