namespace pwm.Model.Responses
{
    /// <summary>
    /// One page of the Work Hours screen, plus the totals of everything the filters
    /// match - the summary cards cover the whole set, not only the page.
    /// </summary>
    public class WorkHoursPageResponse : PageResult<WorkHoursEntryResponse>
    {
        public double TotalHours { get; set; }

        public double RegularHours { get; set; }

        public double OvertimeHours { get; set; }

        public int WorkerCount { get; set; }
    }
}
