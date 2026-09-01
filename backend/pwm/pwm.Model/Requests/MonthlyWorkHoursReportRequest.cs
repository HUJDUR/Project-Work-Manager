using System;

namespace pwm.Model.Requests
{
    public class MonthlyWorkHoursReportRequest
    {
        public int Year { get; set; }

        public int Month { get; set; }

        /// <summary>Null for every worker.</summary>
        public int? UserId { get; set; }

        /// <summary>Null for every project.</summary>
        public int? ProjectId { get; set; }
    }
}
