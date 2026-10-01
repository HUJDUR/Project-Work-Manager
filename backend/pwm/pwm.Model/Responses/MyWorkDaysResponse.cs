namespace pwm.Model.Responses
{
    /// <summary>
    /// One page of a worker's days, newest first, with the totals of the whole
    /// period and every worked day's figures for its trend lines.
    /// </summary>
    public class MyWorkDaysResponse : PageResult<WorkDayResponse>
    {
        public double TotalHours { get; set; }

        /// <summary>Distinct across the period, not the sum of each day's count.</summary>
        public int ProjectCount { get; set; }

        /// <summary>Every day with work in the period, oldest first.</summary>
        public List<WorkDayTotalResponse> Trend { get; set; } = [];
    }

    public class WorkDayResponse
    {
        /// <summary>The Sarajevo day the blocks were started on.</summary>
        public DateOnly Date { get; set; }

        public double Hours { get; set; }

        public int ProjectCount { get; set; }

        /// <summary>A block still running - clocked in, not out yet.</summary>
        public bool InProgress { get; set; }

        /// <summary>In the order they were worked.</summary>
        public List<WorkDayBlockResponse> Blocks { get; set; } = [];
    }

    public class WorkDayBlockResponse
    {
        public int Id { get; set; }

        public int ProjectId { get; set; }

        public string ProjectName { get; set; } = string.Empty;

        public string ProjectCode { get; set; } = string.Empty;

        public string OperationName { get; set; } = string.Empty;

        public DateTime StartedAt { get; set; }

        public DateTime? FinishedAt { get; set; }

        public double Hours { get; set; }

        public string? Note { get; set; }
    }

    public class WorkDayTotalResponse
    {
        public DateOnly Date { get; set; }

        public double Hours { get; set; }

        public int ProjectCount { get; set; }
    }
}
