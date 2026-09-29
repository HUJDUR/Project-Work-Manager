namespace pwm.Model.Responses
{
    /// <summary>
    /// One booked block of work for the Work Hours screen, joined to its worker,
    /// project and operation and split into regular and overtime hours. The ids and
    /// both timestamps ride along so the details form can prefill and write back.
    /// </summary>
    public class WorkHoursEntryResponse
    {
        public int Id { get; set; }

        public int WorkLogId { get; set; }

        public int UserId { get; set; }

        public int ProjectId { get; set; }

        public int OperationTypeId { get; set; }

        public string WorkerName { get; set; } = string.Empty;

        public string WorkerInitials { get; set; } = string.Empty;

        public string ProjectName { get; set; } = string.Empty;

        public string OperationName { get; set; } = string.Empty;

        public DateTime StartedAt { get; set; }

        public DateTime? FinishedAt { get; set; }

        public double RegularHours { get; set; }

        public double OvertimeHours { get; set; }

        /// <summary>The block or its shift is still open.</summary>
        public bool InProgress { get; set; }
    }
}
