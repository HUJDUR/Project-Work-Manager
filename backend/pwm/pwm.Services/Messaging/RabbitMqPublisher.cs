using System.Text.Json;
using RabbitMQ.Client;

namespace pwm.Services.Messaging
{
    /// <summary>
    /// One connection and channel to the broker for everything a process publishes -
    /// report requests from the API, notification pushes from the worker - rather
    /// than a connection per publish. Connects lazily, on the first message, so a
    /// broker that is not up yet fails only that message, not the whole process.
    /// Registered as a singleton.
    /// </summary>
    public sealed class RabbitMqPublisher : IAsyncDisposable
    {
        private readonly RabbitMqOptions _options;
        private readonly SemaphoreSlim _lock = new(1, 1);
        private readonly HashSet<string> _declaredQueues = [];
        private IConnection? _connection;
        private IChannel? _channel;

        public RabbitMqPublisher(RabbitMqOptions options)
        {
            _options = options;
        }

        public async Task PublishAsync<T>(string queue, T message, CancellationToken cancellationToken = default)
        {
            var channel = await GetChannelAsync(queue, cancellationToken);

            await channel.BasicPublishAsync(
                exchange: string.Empty,
                routingKey: queue,
                mandatory: false,
                basicProperties: new BasicProperties { Persistent = true },
                body: JsonSerializer.SerializeToUtf8Bytes(message),
                cancellationToken: cancellationToken);
        }

        private async Task<IChannel> GetChannelAsync(string queue, CancellationToken cancellationToken)
        {
            await _lock.WaitAsync(cancellationToken);
            try
            {
                if (_channel is not { IsOpen: true })
                {
                    var factory = new ConnectionFactory
                    {
                        HostName = _options.HostName,
                        Port = _options.Port,
                        UserName = _options.UserName,
                        Password = _options.Password,
                    };

                    _connection = await factory.CreateConnectionAsync(cancellationToken);
                    _channel = await _connection.CreateChannelAsync(cancellationToken: cancellationToken);
                    _declaredQueues.Clear();
                }

                // Durable, so a broker restart does not drop a message nobody has
                // picked up yet. Declared once per queue per channel.
                if (_declaredQueues.Add(queue))
                {
                    await _channel.QueueDeclareAsync(
                        queue: queue,
                        durable: true,
                        exclusive: false,
                        autoDelete: false,
                        cancellationToken: cancellationToken);
                }

                return _channel;
            }
            finally
            {
                _lock.Release();
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
