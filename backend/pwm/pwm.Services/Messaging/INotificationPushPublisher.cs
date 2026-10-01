namespace pwm.Services.Messaging
{
    /// <summary>
    /// Tells the apps of these accounts that their notifications changed, so they
    /// reload without anyone refreshing by hand. The API does it straight through
    /// SignalR; <c>pwm.Worker</c>, which has no clients of its own, hands it to the
    /// API over RabbitMQ.
    /// </summary>
    public interface INotificationPushPublisher
    {
        Task PublishAsync(IReadOnlyCollection<int> userIds, CancellationToken cancellationToken = default);
    }
}
