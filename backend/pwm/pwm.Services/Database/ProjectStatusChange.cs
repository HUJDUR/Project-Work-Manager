using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using pwm.Services.Business;

namespace pwm.Services.Database
{
    /// <summary>
    /// One recorded move through a project's status life cycle - see
    /// <c>ProjectStatusRules</c> for the legal jumps. Written once per successful
    /// transition, including the row a project's own creation writes (with
    /// <see cref="FromStatusId"/> null), and never edited or deleted - this is
    /// the audit trail a status-driven business process needs.
    /// </summary>
    public class ProjectStatusChange
    {
        [Key]
        public int Id { get; set; }

        public int ProjectId { get; set; }

        [ForeignKey(nameof(ProjectId))]
        [Required]
        public Project Project { get; set; } = null!;

        /// <summary>Null for the row a project's creation writes.</summary>
        public int? FromStatusId { get; set; }

        [ForeignKey(nameof(FromStatusId))]
        public ProjectStatusType? FromStatus { get; set; }

        public int ToStatusId { get; set; }

        [ForeignKey(nameof(ToStatusId))]
        [Required]
        public ProjectStatusType ToStatus { get; set; } = null!;

        public int ChangedByUserId { get; set; }

        [ForeignKey(nameof(ChangedByUserId))]
        [Required]
        public User ChangedByUser { get; set; } = null!;

        [Required]
        public DateTime ChangedAt { get; set; } = DateTime.UtcNow;

        /// <summary>Why the project was rejected - required for that move, null for every other.</summary>
        [MaxLength(StatusChangeRules.ReasonMaxLength)]
        public string? Reason { get; set; }
    }
}
