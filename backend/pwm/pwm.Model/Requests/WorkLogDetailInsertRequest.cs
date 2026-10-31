namespace pwm.Model.Requests
{
    /// <summary>
    /// Hours the office books or corrects by hand. Carries neither a shift nor the
    /// hours: the API puts the block on the worker's shift for that day and works
    /// both the block's and the shift's hours out from the times.
    /// </summary>
    public class WorkLogDetailInsertRequest
    {
        public int UserId { get; set; }

        public int OperationTypeId { get; set; }

        public int ProjectId { get; set; }

        public DateTime StartedAt { get; set; }

        /// <summary>Required - only a clock-in on the phone leaves a block running.</summary>
        public DateTime? FinishedAt { get; set; }

        /// <summary>Optional; blank is stored as none.</summary>
        public string? Note { get; set; }
    }
}
