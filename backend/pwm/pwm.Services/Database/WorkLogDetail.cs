using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using pwm.Services.Business;

namespace pwm.Services.Database
{
    public class WorkLogDetail
    {
        [Key]
        public int Id { get; set; }

        public int WorkLogId { get; set; }

        [ForeignKey(nameof(WorkLogId))]
        [Required]
        public WorkLog WorkLog { get; set; } = null!;

        /// <summary>Whose block of work this is. Always the owner of <see cref="WorkLog"/>.</summary>
        public int UserId { get; set; }

        [ForeignKey(nameof(UserId))]
        [Required]
        public User User { get; set; } = null!;

        public int OperationTypeId { get; set; }

        [ForeignKey(nameof(OperationTypeId))]
        [Required]
        public OperationType OperationType { get; set; } = null!;

        public int ProjectId { get; set; }

        [ForeignKey(nameof(ProjectId))]
        [Required]
        public Project Project { get; set; } = null!;

        [Required]
        public DateTime StartedAt { get; set; }

        /// <summary>Null while the worker is still on this block of work.</summary>
        public DateTime? FinishedAt { get; set; }

        [Required]
        public double Hours { get; set; }

        /// <summary>
        /// The part of <see cref="Hours"/> that is regular time (see <c>OvertimeRules</c>);
        /// the rest is overtime. Kept by <c>MonthlyHourSummary</c> on every write, so the
        /// Work Hours screen can filter, sort and total by it in the database.
        /// </summary>
        [Required]
        public double RegularHours { get; set; }

        /// <summary>Optional - what the worker wanted to add when clocking in.</summary>
        [MaxLength(WorkBookingRules.NoteMaxLength)]
        public string? Note { get; set; }
    }
}
