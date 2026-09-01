using System;

namespace pwm.Model.Responses
{
    public class MonthlyHourReportDetailResponse
    {
        public int Id { get; set; }

        public int MonthlyHourReportId { get; set; }

        public int UserId { get; set; }

        public double TotalHours { get; set; }

        public double RegularHours { get; set; }

        public double OvertimeHours { get; set; }
    }
}
