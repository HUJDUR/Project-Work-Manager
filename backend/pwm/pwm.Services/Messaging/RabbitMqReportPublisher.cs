namespace pwm.Services.Messaging
{
    /// <summary>Report requests, onto the queue <c>pwm.Worker</c> renders from.</summary>
    public sealed class RabbitMqReportPublisher : IReportQueuePublisher
    {
        private readonly RabbitMqPublisher _publisher;
        private readonly RabbitMqOptions _options;

        public RabbitMqReportPublisher(RabbitMqPublisher publisher, RabbitMqOptions options)
        {
            _publisher = publisher;
            _options = options;
        }

        public Task PublishAsync(ReportGenerationMessage message, CancellationToken cancellationToken = default) =>
            _publisher.PublishAsync(_options.ReportQueueName, message, cancellationToken);
    }
}
