using System;
using pwm.Model.Enums;

namespace pwm.Model.SearchObjects
{
    public class ProjectSearchObject : BaseSearchObject
    {
        /// <summary>
        /// Matches the project name or its customer's name: what the desktop
        /// search box sends. <see cref="Name"/> stays a project-name-only filter.
        /// </summary>
        public string? Search { get; set; }

        public string? Name { get; set; }

        public int? CustomerId { get; set; }

        public int? ProjectCategoryId { get; set; }

        public int? ProjectStatusId { get; set; }

        public ProjectPriority? Priority { get; set; }

        public int? CreatedByUserId { get; set; }

        public int? DeliveryCompanyId { get; set; }
    }
}
