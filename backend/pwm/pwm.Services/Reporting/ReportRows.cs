using System;
using System.Collections.Generic;

namespace pwm.Services.Reporting
{
    /// <summary>One worker's month: the payroll line, plus where the hours went.</summary>
    public class MonthlyWorkHoursRow
    {
        public string WorkerName { get; set; } = string.Empty;

        public double RegularHours { get; set; }

        public double OvertimeHours { get; set; }

        public double TotalHours => RegularHours + OvertimeHours;

        public List<MonthlyWorkHoursProjectRow> ByProject { get; set; } = [];
    }

    public class MonthlyWorkHoursProjectRow
    {
        public string ProjectName { get; set; } = string.Empty;

        public double Hours { get; set; }
    }

    /// <summary>One project on one truck.</summary>
    public class TransportLoadRow
    {
        public DateTime LoadDate { get; set; }

        public string ProjectName { get; set; } = string.Empty;

        public string ProjectCode { get; set; } = string.Empty;

        public string CarrierName { get; set; } = string.Empty;

        public string DriverName { get; set; } = string.Empty;

        public string VehicleRegistration { get; set; } = string.Empty;

        /// <summary>Kilograms.</summary>
        public double NetWeight { get; set; }

        public string Status { get; set; } = string.Empty;
    }
}
