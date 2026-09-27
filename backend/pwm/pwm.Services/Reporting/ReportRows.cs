namespace pwm.Services.Reporting
{
    /// <summary>One worker's month: the payroll line.</summary>
    public class MonthlyWorkHoursRow
    {
        public string WorkerName { get; set; } = string.Empty;

        public double RegularHours { get; set; }

        public double OvertimeHours { get; set; }

        public double TotalHours => RegularHours + OvertimeHours;
    }

    /// <summary>One work type's total for the month, summed across every worker and project.</summary>
    public class MonthlyWorkHoursOperationRow
    {
        public string OperationTypeName { get; set; } = string.Empty;

        public double Hours { get; set; }
    }

    /// <summary>One truck's run: the transport itself, plus every project loaded onto it.</summary>
    public class TransportOverviewRow
    {
        public DateTime LoadDate { get; set; }

        public string CarrierName { get; set; } = string.Empty;

        public string DriverName { get; set; } = string.Empty;

        public string VehicleRegistration { get; set; } = string.Empty;

        public string Status { get; set; } = string.Empty;

        /// <summary>Kilograms - the sum of every project's bruto weight on this transport.</summary>
        public double BrutoWeight { get; set; }

        /// <summary>Kilograms - the sum of every project's neto weight on this transport.</summary>
        public double NetoWeight { get; set; }

        public List<TransportProjectRow> Projects { get; set; } = [];
    }

    /// <summary>One project's cargo on a transport.</summary>
    public class TransportProjectRow
    {
        public string ProjectName { get; set; } = string.Empty;

        public string ProjectCode { get; set; } = string.Empty;

        /// <summary>Kilograms.</summary>
        public double BrutoWeight { get; set; }

        /// <summary>Kilograms.</summary>
        public double NetoWeight { get; set; }
    }
}
