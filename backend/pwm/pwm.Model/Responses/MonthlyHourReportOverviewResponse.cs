namespace pwm.Model.Responses
{
    /// <summary>One month on the Monthly Reports screen, opened: the totals, every worker's hours, and the work types.</summary>
    public class MonthlyHourReportOverviewResponse
    {
        public MonthlyHourReportResponse Month { get; set; } = new();

        /// <summary>By name.</summary>
        public List<MonthlyHourReportWorkerResponse> Workers { get; set; } = [];

        /// <summary>Hours per work type, busiest first - every worker's added together.</summary>
        public List<MonthlyHourReportOperationResponse> Operations { get; set; } = [];
    }

    public class MonthlyHourReportWorkerResponse
    {
        public int UserId { get; set; }

        public string WorkerName { get; set; } = string.Empty;

        public int DaysWorked { get; set; }

        public double RegularHours { get; set; }

        public double OvertimeHours { get; set; }

        public double TotalHours { get; set; }
    }

    public class MonthlyHourReportOperationResponse
    {
        public string OperationName { get; set; } = string.Empty;

        public double Hours { get; set; }
    }
}
