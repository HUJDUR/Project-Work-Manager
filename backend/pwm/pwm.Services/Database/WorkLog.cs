using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace pwm.Services.Database
{
    public class WorkLog
    {
        [Key]
        public int Id { get; set; }

        public int UserId { get; set; }

        [ForeignKey(nameof(UserId))]
        [Required]
        public User User { get; set; } = null!;

        [Required]
        public DateTime ClockedIn { get; set; }

        /// <summary>Null while the shift is still open - the worker has not clocked out.</summary>
        public DateTime? ClockedOut { get; set; }

        [Required]
        public double Hours { get; set; }

        /// <summary>
        /// Stamped by <c>pwm.Worker</c>'s missed clock-out watchdog the moment it warns
        /// admins and project managers about this shift, so a still-open shift is only
        /// ever reported once rather than on every poll.
        /// </summary>
        public DateTime? MissedClockOutNotifiedAt { get; set; }
    }
}
