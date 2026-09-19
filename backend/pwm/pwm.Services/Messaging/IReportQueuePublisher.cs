namespace pwm.Services.Messaging
{
    /// <summary>The API side of the queue - see <see cref="ReportGenerationMessage"/>.</summary>
    public interface IReportQueuePublisher
    {
        Task PublishAsync(ReportGenerationMessage message, CancellationToken cancellationToken = default);
    }
}
