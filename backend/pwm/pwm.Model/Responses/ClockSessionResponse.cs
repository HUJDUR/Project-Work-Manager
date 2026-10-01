namespace pwm.Model.Responses
{
    /// <summary>
    /// One block of work booked through clocking in - running while
    /// <see cref="FinishedAt"/> is null - with its project and operation named.
    /// </summary>
    public class ClockSessionResponse
    {
        public int WorkLogDetailId { get; set; }

        /// <summary>The shift (the day) it belongs to.</summary>
        public int WorkLogId { get; set; }

        public int ProjectId { get; set; }

        /// <summary>"26-015 - Staircase module".</summary>
        public string ProjectLabel { get; set; } = string.Empty;

        public int OperationTypeId { get; set; }

        public string OperationName { get; set; } = string.Empty;

        public DateTime StartedAt { get; set; }

        public DateTime? FinishedAt { get; set; }

        public double Hours { get; set; }

        public string? Note { get; set; }
    }

    /// <summary>Everything the Clock In screen needs, for the signed-in account.</summary>
    public class ClockInOptionsResponse
    {
        /// <summary>The session running now, if there is one.</summary>
        public ClockSessionResponse? Session { get; set; }

        /// <summary>Projects in production - what the shop floor books against.</summary>
        public List<ClockInOptionResponse> Projects { get; set; } = [];

        /// <summary>The operations this account is qualified for.</summary>
        public List<ClockInOptionResponse> Operations { get; set; } = [];
    }

    public class ClockInOptionResponse
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;
    }
}
