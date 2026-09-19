using System.Text.Json;
using RabbitMQ.Client;

namespace pwm.Services.Messaging
{
    /// <summary>
    /// Connects lazily, on the first report request rather than at API startup, so
    /// a broker that is not up yet fails only report generation - not the whole API.
    /// One instance is shared for the process's lifetime (see its DI registration).
    /// </summary>
    public sealed class RabbitMqReportPublisher : IReportQueuePublisher, IAsyncDisposable
    {
        private readonly RabbitMqOptions _options;
        private readonly SemaphoreSlim _connectLock = new(1, 1);
        private IConnection? _connection;
        private IChannel? _channel;

        public RabbitMqReportPublisher(RabbitMqOptions options)
        {
            _options = options;
        }

        public async Task PublishAsync(ReportGenerationMessage message, CancellationToken cancellationToken = default)
        {
            var channel = await GetChannelAsync(cancellationToken);
            var body = JsonSerializer.SerializeToUtf8Bytes(message);

            await channel.BasicPublishAsync(
                exchange: string.Empty,
                routingKey: _options.ReportQueueName,
                mandatory: false,
                basicProperties: new BasicProperties { Persistent = true },
                body: body,
                cancellationToken: cancellationToken);
        }

        private async Task<IChannel> GetChannelAsync(CancellationToken cancellationToken)
        {
            if (_channel is { IsOpen: true })
            {
                return _channel;
            }

            await _connectLock.WaitAsync(cancellationToken);
            try
            {
                if (_channel is { IsOpen: true })
                {
                    return _channel;
                }

                var factory = new ConnectionFactory
                {
                    HostName = _options.HostName,
                    Port = _options.Port,
                    UserName = _options.UserName,
                    Password = _options.Password,
                };

                _connection = await factory.CreateConnectionAsync(cancellationToken);
                _channel = await _connection.CreateChannelAsync(cancellationToken: cancellationToken);

                // Durable so a broker restart does not drop a report that was
                // requested but not yet picked up by the worker.
                await _channel.QueueDeclareAsync(
                    queue: _options.ReportQueueName,
                    durable: true,
                    exclusive: false,
                    autoDelete: false,
                    cancellationToken: cancellationToken);

                return _channel;
            }
            finally
            {
                _connectLock.Release();
            }
        }

        public async ValueTask DisposeAsync()
        {
            if (_channel is not null)
            {
                await _channel.CloseAsync();
            }

            if (_connection is not null)
            {
                await _connection.CloseAsync();
            }
        }
    }
}
