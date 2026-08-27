using System;

namespace pwm.Model.SearchObjects
{
    public class ProjectSearchObject : BaseSearchObject
    {
        public string? Name { get; set; }

        public int? CustomerId { get; set; }

        public int? ProjectCategoryId { get; set; }

        public int? ProjectStatusId { get; set; }

        public int? DeliveryCompanyId { get; set; }
    }
}
