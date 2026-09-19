namespace pwm.Model.Enums
{
    /// <summary>
    /// A <c>GeneratedReport</c>'s place in the queue-and-build pipeline: the API
    /// only ever writes <see cref="Pending"/>; the worker that actually renders
    /// the PDF is the only thing that ever moves it on from there.
    /// </summary>
    public enum ReportStatus
    {
        Pending = 0,
        Processing = 1,
        Completed = 2,
        Failed = 3,
    }
}
