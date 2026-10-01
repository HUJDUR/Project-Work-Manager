namespace pwm.Services.Messaging
{
    /// <summary>
    /// Connection details for the broker sitting between the API and <c>pwm.Worker</c>.
    /// Bound from the <c>RabbitMq</c> configuration section, which no longer lives in
    /// appsettings.json - all five values come from <c>backend/.env</c> (host/port) or
    /// docker-compose.yml's <c>environment:</c> block (the containers' own host/port,
    /// plus the same credentials and queue name read from <c>.env</c>). The defaults
    /// below only cover a process that somehow starts with neither set.
    /// </summary>
    public class RabbitMqOptions
    {
        public string HostName { get; set; } = "localhost";
        public int Port { get; set; } = 5672;
        public string UserName { get; set; } = "guest";
        public string Password { get; set; } = "guest";

        /// <summary>Where the API publishes a report request and the worker consumes it.</summary>
        public string ReportQueueName { get; set; } = "report-generation";

        /// <summary>Where the worker queues "these accounts have new notifications"
        /// and the API relays it to SignalR.</summary>
        public string NotificationQueueName { get; set; } = "notification-push";
    }
}
