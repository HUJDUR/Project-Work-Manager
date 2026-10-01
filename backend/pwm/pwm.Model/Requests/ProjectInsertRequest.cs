using pwm.Model.Enums;

namespace pwm.Model.Requests
{
    /// <summary>
    /// Deliberately carries neither <c>ProjectStatusId</c> nor
    /// <c>ProductionStartDate</c>: a project always starts life "Potential" and
    /// reaches the shop floor only through <c>ProjectController.ChangeStatus</c>,
    /// which is also the only thing that ever sets <c>ProductionStartDate</c>.
    /// This request cannot express either, on insert or on update.
    /// </summary>
    public class ProjectInsertRequest
    {
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

    }
}
