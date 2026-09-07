using System;
using System.ComponentModel.DataAnnotations;

namespace pwm.Services.Database
{
    /// <summary>
    /// The reports the office can produce. The rows are fixed - each one has its own
    /// PDF and its own code path in <c>ReportService</c>, and the Ids match
    /// <c>pwm.Model.Enums.ReportType</c>, which is what that code branches on.
    /// </summary>
    public class ReportType
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(100)]
        public string Description { get; set; } = string.Empty;
    }
}
