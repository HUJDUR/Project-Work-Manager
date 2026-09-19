namespace pwm.Model.Requests
{
    /// <summary>
    /// Unlike every other insert request, this one carries its own <see cref="Id"/>:
    /// <c>ReportType.Id</c> is <c>ValueGeneratedNever()</c> because the seeded rows mirror
    /// <c>pwm.Model.Enums.ReportType</c>, which <c>ReportService</c> branches on. A row added
    /// here has no matching case in that switch, so it lists but can never actually run.
    /// </summary>
    public class ReportTypeInsertRequest : IReportTypeRequest
    {
        public int Id { get; set; }

        public string Description { get; set; } = string.Empty;
    }
}
