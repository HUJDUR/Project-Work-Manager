using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using pwm.Model.Enums;
using pwm.Model.Requests;
using pwm.Services.Database;
using pwm.Services.Messaging;
using pwm.Services.Reporting;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using ReportKind = pwm.Model.Enums.ReportType;

namespace pwm.Worker;

/// <summary>
/// The separate process the spec calls for: everything here runs in its own
/// container, off RabbitMQ, never inside pwm.WebAPI. One report at a time,
/// deliberately - QuestPDF rendering is CPU-bound and the shop's report volume
/// does not call for more.
/// </summary>
public class ReportGenerationWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly RabbitMqOptions _options;
    private readonly ILogger<ReportGenerationWorker> _logger;

    private IChannel? _channel;

    /// <summary>
    /// Exponential backoff between attempts at the same message - 1s, 2s, 4s, 8s -
    /// per the seminar's own anti-pattern list (Appendix A.1). One message is still
    /// only ever acked once, in <see cref="HandleMessageAsync"/>'s <c>finally</c>;
    /// this just gives a transient failure (a DB blip, say) a few tries first,
    /// instead of the row going straight to <c>Failed</c> on the first hiccup.
    /// </summary>
    private static readonly TimeSpan[] RetryDelays =
    [
        TimeSpan.FromSeconds(1),
        TimeSpan.FromSeconds(2),
        TimeSpan.FromSeconds(4),
        TimeSpan.FromSeconds(8),
    ];

    public ReportGenerationWorker(
        IServiceScopeFactory scopeFactory,
        RabbitMqOptions options,
        ILogger<ReportGenerationWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _options = options;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // The broker may not be up yet - e.g. compose still starting sqlserver's
        // healthcheck first - so a failed connection is retried rather than
        // crashing the container.
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ConnectAndConsumeAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Lost the connection to RabbitMQ; retrying in 5s.");
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
        }
    }

    private async Task ConnectAndConsumeAsync(CancellationToken stoppingToken)
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
        _channel = channel;

        await channel.QueueDeclareAsync(
            queue: _options.ReportQueueName,
            durable: true,
            exclusive: false,
            autoDelete: false,
            cancellationToken: stoppingToken);

        // One report in flight at a time - see the class doc comment.
        await channel.BasicQosAsync(
            prefetchSize: 0, prefetchCount: 1, global: false, cancellationToken: stoppingToken);

        var consumer = new AsyncEventingBasicConsumer(channel);
        consumer.ReceivedAsync += async (_, args) => await HandleMessageAsync(args, stoppingToken);

        await channel.BasicConsumeAsync(
            queue: _options.ReportQueueName,
            autoAck: false,
            consumer: consumer,
            cancellationToken: stoppingToken);

        _logger.LogInformation(
            "Listening on \"{Queue}\" at {Host}:{Port}.",
            _options.ReportQueueName, _options.HostName, _options.Port);

        // BasicConsumeAsync returns as soon as consuming starts; stay alive until
        // cancelled or the connection drops, at which point ExecuteAsync reconnects.
        await Task.Delay(Timeout.InfiniteTimeSpan, stoppingToken);
    }

    /// <summary>
    /// A failed build is retried in place, with <see cref="RetryDelays"/> between
    /// attempts, before this gives up on it. However it ends, the message is acked
    /// in <c>finally</c>: a report that can never succeed (its row deleted, say)
    /// would otherwise redeliver forever. A failure that survives every retry is
    /// recorded on the row instead, in <see cref="MarkFailedAsync"/>, which is what
    /// the Reports screen actually surfaces to whoever asked for it.
    /// </summary>
    private async Task HandleMessageAsync(BasicDeliverEventArgs args, CancellationToken stoppingToken)
    {
        var reportId = -1;

        try
        {
            var message = JsonSerializer.Deserialize<ReportGenerationMessage>(args.Body.Span)
                ?? throw new InvalidOperationException("Empty report generation message.");
            reportId = message.GeneratedReportId;

            _logger.LogInformation("Report {ReportId}: starting.", reportId);

            await using var scope = _scopeFactory.CreateAsyncScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<PWMDbContext>();
            var builder = scope.ServiceProvider.GetRequiredService<ReportBuilder>();

            for (var attempt = 0; ; attempt++)
            {
                try
                {
                    await BuildAndStoreAsync(dbContext, builder, reportId, stoppingToken);
                    break;
                }
                catch (Exception ex) when (attempt < RetryDelays.Length)
                {
                    _logger.LogWarning(ex,
                        "Report {ReportId}: attempt {Attempt} of {Total} failed, retrying in {Delay}.",
                        reportId, attempt + 1, RetryDelays.Length + 1, RetryDelays[attempt]);
                    await Task.Delay(RetryDelays[attempt], stoppingToken);
                }
            }

            _logger.LogInformation("Report {ReportId}: completed.", reportId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Report {ReportId}: failed.", reportId);
            await MarkFailedAsync(reportId, ex, stoppingToken);
        }
        finally
        {
            if (_channel is not null)
            {
                await _channel.BasicAckAsync(args.DeliveryTag, multiple: false, cancellationToken: stoppingToken);
            }
        }
    }

    private static async Task BuildAndStoreAsync(
        PWMDbContext dbContext, ReportBuilder builder, int reportId, CancellationToken stoppingToken)
    {
        var report = await dbContext.GeneratedReports.FirstOrDefaultAsync(x => x.Id == reportId, stoppingToken)
            ?? throw new InvalidOperationException($"GeneratedReport {reportId} does not exist.");

        report.Status = ReportStatus.Processing;
        await dbContext.SaveChangesAsync(stoppingToken);

        var content = (ReportKind)report.ReportTypeId switch
        {
            ReportKind.MonthlyWorkHours => await builder.BuildMonthlyWorkHoursAsync(
                Read<MonthlyWorkHoursReportRequest>(report.Parameters)),
            ReportKind.TransportLoads => await builder.BuildTransportLoadsAsync(
                Read<TransportLoadsReportRequest>(report.Parameters)),
            _ => throw new InvalidOperationException($"Report type {report.ReportTypeId} cannot be built."),
        };

        report.Content = content;
        report.Status = ReportStatus.Completed;
        await dbContext.SaveChangesAsync(stoppingToken);
    }

    private async Task MarkFailedAsync(int reportId, Exception ex, CancellationToken stoppingToken)
    {
        if (reportId < 0)
        {
            // The message itself could not even be read - nothing to mark.
            return;
        }

        try
        {
            await using var scope = _scopeFactory.CreateAsyncScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<PWMDbContext>();

            var report = await dbContext.GeneratedReports.FirstOrDefaultAsync(x => x.Id == reportId, stoppingToken);
            if (report is null)
            {
                return;
            }

            report.Status = ReportStatus.Failed;
            report.ErrorMessage = ex.Message.Length > 1000 ? ex.Message[..1000] : ex.Message;
            await dbContext.SaveChangesAsync(stoppingToken);
        }
        catch (Exception markEx)
        {
            // The one case a failure can go unrecorded: the database itself is
            // unreachable. Logged so a crash mid-review is reproducible from here.
            _logger.LogError(markEx, "Report {ReportId}: could not even record the failure.", reportId);
        }
    }

    private static T Read<T>(string parameters) where T : new() =>
        JsonSerializer.Deserialize<T>(parameters) ?? new T();
}
