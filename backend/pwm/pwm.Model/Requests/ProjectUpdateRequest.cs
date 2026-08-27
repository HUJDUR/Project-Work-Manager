using System;

namespace pwm.Model.Requests
{
    public class ProjectUpdateRequest
    {
        public int CustomerId { get; set; }

        public string Name { get; set; } = string.Empty;

        public double Weight { get; set; }

        public int ProjectCategoryId { get; set; }

        public DateTime? DeliveryDate { get; set; }

        public int? DeliveryCompanyId { get; set; }

        public DateTime CreationDate { get; set; }

        public DateTime? ProductionStartDate { get; set; }

        public int ProjectStatusId { get; set; }
    }
}
