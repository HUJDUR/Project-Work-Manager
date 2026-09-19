using pwm.Model.Enums;

namespace pwm.Model.Responses
{
    public class ProjectResponse
    {
        public int Id { get; set; }

        public int CustomerId { get; set; }

        public string Name { get; set; } = string.Empty;

        /// <summary>The shop's own reference for the job, e.g. MU-2201.</summary>
        public string Code { get; set; } = string.Empty;

        public string? Description { get; set; }

        public string? Notes { get; set; }

        public ProjectPriority Priority { get; set; } = ProjectPriority.Medium;

        public double Weight { get; set; }

        public int ProjectCategoryId { get; set; }

        public DateTime? DeliveryDate { get; set; }

        public int? DeliveryCompanyId { get; set; }

        public DateTime CreationDate { get; set; }

        public DateTime? ProductionStartDate { get; set; }

        public int ProjectStatusId { get; set; }

        /// <summary>Who raised the project.</summary>
        public int CreatedByUserId { get; set; }
    }
}
