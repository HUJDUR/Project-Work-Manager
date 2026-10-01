using System.Text.Json;
using pwm.Services.Messaging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace pwm.WebAPI.Hubs
{
    /// <summary>
    /// Passes on the notification pushes <c>pwm.Worker</c> queues - its missed
    /// clock-out warnings - to SignalR, which only this process can reach. This is
    /// a relay, not background work: the worker still does the work in its own
    /// container; this only forwards its "tell these accounts" onward.
    /// </summary>
    public class NotificationPushRelay : BackgroundService
    {
        private readonly RabbitMqOptions _options;
        private readonly HubNotificationPushPublisher _hub;
        private readonly ILogger<NotificationPushRelay> _logger;

        public NotificationPushRelay(
            RabbitMqOptions options,
            HubNotificationPushPublisher hub,
            ILogger<NotificationPushRelay> logger)
        {
            _options = options;
            _hub = hub;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            // The broker may not be up yet, or may drop - reconnect rather than let
            // live notifications quietly stop for the rest of the process's life.
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await ConsumeAsync(stoppingToken);
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Notification push relay lost RabbitMQ; retrying in 5s.");
                    await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
                }
            }
        }

        private async Task ConsumeAsync(CancellationToken stoppingToken)
        {
            var factory = new ConnectionFactory
            {
                HostName = _options.HostName,
                Port = _options.Port,
                UserName = _options.UserName,
                Password = _options.Password,
            };

            await using var connection = await factory.CreateConnectionAsync(stoppingToken);
            await using var channel = await connection.CreateChannelAsync(cancellationToken: stoppingToken);

            await channel.QueueDeclareAsync(
                queue: _options.NotificationQueueName,
                durable: true,
                exclusive: false,
                autoDelete: false,
                cancellationToken: stoppingToken);

            var consumer = new AsyncEventingBasicConsumer(channel);
            consumer.ReceivedAsync += async (_, args) =>
            {
                try
                {
                    var message = JsonSerializer.Deserialize<NotificationPushMessage>(args.Body.Span);
                    if (message is { UserIds.Count: > 0 })
                    {
                        await _hub.PublishAsync(message.UserIds, stoppingToken);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Dropped an unreadable notification push.");
                }
                finally
                {
                    await channel.BasicAckAsync(args.DeliveryTag, multiple: false, cancellationToken: stoppingToken);
                }
            };

            await channel.BasicConsumeAsync(
                queue: _options.NotificationQueueName,
                autoAck: false,
                consumer: consumer,
                cancellationToken: stoppingToken);

            _logger.LogInformation("Relaying notification pushes from \"{Queue}\".", _options.NotificationQueueName);

            await Task.Delay(Timeout.InfiniteTimeSpan, stoppingToken);
        }
    }
}
