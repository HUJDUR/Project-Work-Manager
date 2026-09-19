namespace pwm.Services.Messaging
{
    /// <summary>
    /// Connection details for the broker sitting between the API and <c>pwm.Worker</c>.
    /// Bound from the <c>RabbitMq</c> configuration section - see <c>appsettings.json</c>
    /// and, for the password, <c>backend/.env</c>.
    /// </summary>
    public class RabbitMqOptions
    {
        public string HostName { get; set; } = "localhost";
        public int Port { get; set; } = 5672;
        public string UserName { get; set; } = "guest";
        public string Password { get; set; } = "guest";

        /// <summary>Where the API publishes a report request and the worker consumes it.</summary>
        public string ReportQueueName { get; set; } = "report-generation";
    }
}
