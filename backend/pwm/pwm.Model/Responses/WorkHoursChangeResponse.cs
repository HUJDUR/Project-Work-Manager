namespace pwm.Model.Responses
{
    /// <summary>One row of a work-hours entry's history, newest first.</summary>
    public class WorkHoursChangeResponse
    {
        public int Id { get; set; }

        /// <summary>"Added", "Changed" or "Deleted".</summary>
        public string Action { get; set; } = string.Empty;

        public string ChangedByName { get; set; } = string.Empty;

        public DateTime ChangedAt { get; set; }

        /// <summary>"26-015 Staircase module · Welding · 30.09.2026 07:00-15:00 (8 h)" - null for an addition.</summary>
        public string? Before { get; set; }

        /// <summary>The same, as it is now - null for a deletion.</summary>
        public string? After { get; set; }
    }
}
