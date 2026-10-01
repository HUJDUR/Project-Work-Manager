using Microsoft.Extensions.Logging;

namespace pwm.Services.Messaging
{
    /// <summary>
    /// <c>pwm.Worker</c>'s side of a notification push: the accounts go onto the queue
    /// the API relays to SignalR. A broker that is down loses only the push - the
    /// notification itself is already saved, and the app shows it on its next load.
    /// </summary>
    public sealed class RabbitMqNotificationPushPublisher : INotificationPushPublisher
    {
        private readonly RabbitMqPublisher _publisher;
        private readonly RabbitMqOptions _options;
        private readonly ILogger<RabbitMqNotificationPushPublisher> _logger;

        public RabbitMqNotificationPushPublisher(
            RabbitMqPublisher publisher,
            RabbitMqOptions options,
            ILogger<RabbitMqNotificationPushPublisher> logger)
        {
            _publisher = publisher;
            _options = options;
            _logger = logger;
        }

        public async Task PublishAsync(IReadOnlyCollection<int> userIds, CancellationToken cancellationToken = default)
        {
            try
            {
                await _publisher.PublishAsync(
                    _options.NotificationQueueName, new NotificationPushMessage(userIds), cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not queue a notification push for {Count} account(s).", userIds.Count);
            }
        }
    }
}
