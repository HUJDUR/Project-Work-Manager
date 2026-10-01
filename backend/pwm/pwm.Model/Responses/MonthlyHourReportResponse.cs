namespace pwm.Model.Responses
{
    public class MonthlyHourReportResponse
    {
        public int Id { get; set; }

        public int Year { get; set; }

        public int Month { get; set; }

        public double TotalHours { get; set; }

        public double RegularHours { get; set; }

        public double OvertimeHours { get; set; }

        public int WorkerCount { get; set; }
    }
}
