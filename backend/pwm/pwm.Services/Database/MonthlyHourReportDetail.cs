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
        public int TotalHours { get; set; }
    }
}
