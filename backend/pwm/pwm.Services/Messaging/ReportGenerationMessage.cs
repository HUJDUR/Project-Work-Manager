namespace pwm.Services.Messaging
{
    /// <summary>
    /// Names the row, nothing else. The worker reads <c>ReportTypeId</c> and
    /// <c>Parameters</c> back off the <c>GeneratedReport</c> row itself, so the
    /// message and the row it points at can never disagree about what was asked for.
    /// </summary>
    public record ReportGenerationMessage(int GeneratedReportId);
}
