namespace pwm.Model.Enums
{
    /// <summary>
    /// The reports the office can produce. Hardcoded rather than a lookup table:
    /// each one is a different PDF with its own parameters and its own code path.
    /// </summary>
    public enum ReportType
    {
        MonthlyWorkHours = 1,
        TransportLoads = 2,
    }
}
