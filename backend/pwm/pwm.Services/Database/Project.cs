using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

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

        public double Weight { get; set; }

        public int ProjectCategoryId { get; set; }

        [ForeignKey(nameof(ProjectCategoryId))]
        [Required]
        public ProjectCategory ProjectCategory { get; set; } = null!;

        public DateTime? DeliveryDate { get; set; }

        public int? DeliveryCompanyId { get; set; }

        [ForeignKey(nameof(DeliveryCompanyId))]
        [Required]
        public Company? DeliveryCompany { get; set; }

        [Required]
        public DateTime CreationDate { get; set; } = DateTime.UtcNow;

        [Required]
        public DateTime? ProductionStartDate { get; set; }

        public int ProjectStatusId { get; set; }

        [ForeignKey(nameof(ProjectStatusId))]
        [Required]
        public ProjectStatusType ProjectStatus { get; set; } = null!;
    }
}
