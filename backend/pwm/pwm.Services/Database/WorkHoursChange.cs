using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using pwm.Model.Enums;

namespace pwm.Services.Database
{
    /// <summary>
    /// One correction the office made to somebody's work hours - who made it, when,
    /// and what the block said before and after, in words. Written with every add,
    /// edit and delete done by hand (not with a worker's own clock-in/out), and
    /// never edited: the trail of changes the work-hours record keeps.
    /// </summary>
    public class WorkHoursChange
    {
        public const int SnapshotMaxLength = 300;

        [Key]
        public int Id { get; set; }

        /// <summary>
        /// The block it is about. Cleared, not cascaded, when the block is deleted -
        /// the "Deleted" row is exactly the one that has to outlive it.
        /// </summary>
        public int? WorkLogDetailId { get; set; }

        [ForeignKey(nameof(WorkLogDetailId))]
        public WorkLogDetail? WorkLogDetail { get; set; }

        /// <summary>Whose hours they are.</summary>
        public int WorkerId { get; set; }

        [ForeignKey(nameof(WorkerId))]
        [Required]
        public User Worker { get; set; } = null!;

        public int ChangedByUserId { get; set; }

        [ForeignKey(nameof(ChangedByUserId))]
        [Required]
        public User ChangedByUser { get; set; } = null!;

        [Required]
        public DateTime ChangedAt { get; set; }

        public WorkHoursChangeAction Action { get; set; }

        /// <summary>The block as it was - null for an addition.</summary>
        [MaxLength(SnapshotMaxLength)]
        public string? Before { get; set; }

        /// <summary>The block as it is now - null for a deletion.</summary>
        [MaxLength(SnapshotMaxLength)]
        public string? After { get; set; }
    }
}
