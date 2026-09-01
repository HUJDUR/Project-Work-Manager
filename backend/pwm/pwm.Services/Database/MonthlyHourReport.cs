using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace pwm.Services.Database
{
    public class MonthlyHourReport
    {
        [Key]
        public int Id { get; set; }

        [Range(2000, 2100)]
        [Required]
        public int Year { get; set; }

        [Range(1, 12)]
        [Required]
        public int Month { get; set; }

        [Required]
        public double TotalHours { get; set; }
    }
}
