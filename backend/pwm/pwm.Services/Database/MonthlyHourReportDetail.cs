using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace pwm.Services.Database
{
    public class MonthlyHourReportDetail
    {
        [Key]
        public int Id { get; set; }

        public int MonthlyHourReportId { get; set; }

        [ForeignKey(nameof(MonthlyHourReportId))]
        [Required]
        public MonthlyHourReport MonthlyHourReport { get; set; } = null!;

        public int UserId { get; set; }

        [ForeignKey(nameof(UserId))]
        [Required]
        public User User { get; set; } = null!;

        [Required]
        public double TotalHours { get; set; }

        /// <summary>The first eight hours of each of this worker's days in the month.</summary>
        [Required]
        public double RegularHours { get; set; }

        /// <summary>Everything past eight hours on a day.</summary>
        [Required]
        public double OvertimeHours { get; set; }
    }
}
