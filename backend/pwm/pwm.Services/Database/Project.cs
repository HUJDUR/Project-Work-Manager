using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using pwm.Model.Enums;

namespace pwm.Services.Database
{
    public class Project
    {
        [Key]
        public int Id { get; set; }

        public int CustomerId { get; set; }

        [ForeignKey(nameof(CustomerId))]
        [Required]
        public Company Customer { get; set; } = null!;

        [Required]
        [MaxLength(200)]
        public string Name { get; set; } = string.Empty;

        /// <summary>The shop's own reference for the job, e.g. MU-2201.</summary>
        [Required]
        [MaxLength(50)]
        public string Code { get; set; } = string.Empty;

        [MaxLength(1000)]
        public string? Description { get; set; }

        [MaxLength(1000)]
        public string? Notes { get; set; }

        [Required]
        public ProjectPriority Priority { get; set; } = ProjectPriority.Medium;

        public double Weight { get; set; }

        public int ProjectCategoryId { get; set; }

        [ForeignKey(nameof(ProjectCategoryId))]
        [Required]
        public ProjectCategory ProjectCategory { get; set; } = null!;

        public DateTime? DeliveryDate { get; set; }

        public int? DeliveryCompanyId { get; set; }

        [ForeignKey(nameof(DeliveryCompanyId))]
        public Company? DeliveryCompany { get; set; }

        [Required]
        public DateTime CreationDate { get; set; } = DateTime.UtcNow;

        /// <summary>Null until the project reaches the shop floor.</summary>
        public DateTime? ProductionStartDate { get; set; }

        public int ProjectStatusId { get; set; }

        [ForeignKey(nameof(ProjectStatusId))]
        [Required]
        public ProjectStatusType ProjectStatus { get; set; } = null!;

        /// <summary>Who raised the project. Every project has an author.</summary>
        public int CreatedByUserId { get; set; }

        [ForeignKey(nameof(CreatedByUserId))]
        [Required]
        public User CreatedBy { get; set; } = null!;
    }
}
