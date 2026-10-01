using System.ComponentModel.DataAnnotations;

namespace pwm.Services.Database
{
    /// <summary>
    /// One month of the payroll summary - see <c>MonthlyHourSummary</c>, which keeps
    /// it true to the work booked. Read by the Monthly Reports screen.
    /// </summary>
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

        /// <summary>The first eight hours of each worker's days, added up.</summary>
        [Required]
        public double RegularHours { get; set; }

        /// <summary>Everything past eight hours on a day, added up.</summary>
        [Required]
        public double OvertimeHours { get; set; }

        /// <summary>How many workers booked anything in the month.</summary>
        [Required]
        public int WorkerCount { get; set; }
    }
}
