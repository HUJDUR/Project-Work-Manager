namespace pwm.Services.Messaging
{
    /// <summary>
    /// "These accounts have new notifications" - what <c>pwm.Worker</c> sends the API
    /// over RabbitMQ, since only the API holds the SignalR connections to tell them.
    /// </summary>
    public record NotificationPushMessage(IReadOnlyCollection<int> UserIds);
}
