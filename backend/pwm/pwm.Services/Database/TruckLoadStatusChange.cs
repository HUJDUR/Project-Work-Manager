using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace pwm.Services.Database
{
    /// <summary>
    /// One recorded move through a transport's status life cycle - see
    /// <c>TruckLoadStatusRules</c> for the legal jumps. Written once per
    /// successful transition, including the row a load's own creation writes
    /// (with <see cref="FromStatusId"/> null), and never edited or deleted -
    /// the audit trail behind its life cycle.
    /// </summary>
    public class TruckLoadStatusChange
    {
        [Key]
        public int Id { get; set; }

        public int TruckLoadId { get; set; }

        [ForeignKey(nameof(TruckLoadId))]
        [Required]
        public TruckLoad TruckLoad { get; set; } = null!;

        /// <summary>Null for the row a load's creation writes.</summary>
        public int? FromStatusId { get; set; }

        [ForeignKey(nameof(FromStatusId))]
        public TruckLoadStatusType? FromStatus { get; set; }

        public int ToStatusId { get; set; }

        [ForeignKey(nameof(ToStatusId))]
        [Required]
        public TruckLoadStatusType ToStatus { get; set; } = null!;

        public int ChangedByUserId { get; set; }

        [ForeignKey(nameof(ChangedByUserId))]
        [Required]
        public User ChangedByUser { get; set; } = null!;

        [Required]
        public DateTime ChangedAt { get; set; } = DateTime.UtcNow;
    }
}
