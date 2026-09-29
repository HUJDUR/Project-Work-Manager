namespace pwm.Model.Responses
{
    /// <summary>
    /// Everything the desktop's Dashboard shows, aggregated on the server - see
    /// <c>DashboardService</c>. Weights are in kilograms.
    /// </summary>
    public class DashboardResponse
    {
        public int WindowDays { get; set; }

        public double HoursLogged { get; set; }

        /// <summary>Projects neither Delivered nor Rejected.</summary>
        public int ActiveProjects { get; set; }

        public int InProduction { get; set; }

        /// <summary>Active production workers.</summary>
        public int ActiveWorkers { get; set; }

        /// <summary>Distinct workers with hours booked inside the window.</summary>
        public int WorkersWithBookings { get; set; }

        public int Transports { get; set; }

        public double ShippedWeight { get; set; }

        public List<DashboardSliceResponse> HoursByProject { get; set; } = [];

        public List<DashboardSliceResponse> HoursByOperation { get; set; } = [];

        public List<DashboardWorkResponse> RecentWork { get; set; } = [];

        public List<DashboardTransportResponse> RecentTransports { get; set; } = [];

        /// <summary>Empty unless the caller is an Admin - the only role the Activities screen is open to.</summary>
        public List<DashboardActivityResponse> RecentActivity { get; set; } = [];
    }

    public class DashboardSliceResponse
    {
        public string Label { get; set; } = string.Empty;

        /// <summary>A project's code; null for an operation.</summary>
        public string? ShortLabel { get; set; }

        public double Value { get; set; }
    }

    public class DashboardWorkResponse
    {
        public string WorkerName { get; set; } = string.Empty;

        public string WorkerInitials { get; set; } = string.Empty;

        public string ProjectName { get; set; } = string.Empty;

        public string OperationName { get; set; } = string.Empty;

        public double Hours { get; set; }

        public DateTime StartedAt { get; set; }
    }

    public class DashboardTransportResponse
    {
        public string DriverName { get; set; } = string.Empty;

        public string VehicleRegistration { get; set; } = string.Empty;

        public string CarrierName { get; set; } = string.Empty;

        public DateTime LoadDate { get; set; }

        public double NetWeight { get; set; }
    }

    public class DashboardActivityResponse
    {
        public string Title { get; set; } = string.Empty;

        public string ActorName { get; set; } = string.Empty;

        public DateTime Date { get; set; }
    }
}
