namespace pwm.Model.Responses
{
    /// <summary>One row of a project's status history - the audit trail behind its
    /// life cycle. Names are resolved server-side rather than left as ids, since
    /// this is read straight into a list with nothing else to join them against.</summary>
    public class ProjectStatusChangeResponse
    {
        public int Id { get; set; }

        /// <summary>Null for the row a project's creation writes.</summary>
        public string? FromStatusName { get; set; }

        public string ToStatusName { get; set; } = string.Empty;

        public int ChangedByUserId { get; set; }

        public string ChangedByName { get; set; } = string.Empty;

        public DateTime ChangedAt { get; set; }

        /// <summary>Set only on a rejection.</summary>
        public string? Reason { get; set; }
    }
}
