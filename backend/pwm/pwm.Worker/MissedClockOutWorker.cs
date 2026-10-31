using Microsoft.EntityFrameworkCore;
using pwm.Model.Access;
using pwm.Services.Business;
using pwm.Services.Database;
using pwm.Common.Services.Time;

namespace pwm.Worker;

/// <summary>
/// The one shift event a worker cannot self-report: a clock-out that never
/// happened. Everything else the desktop's notifications screen sends is
/// someone actively choosing to send it (see <c>NotificationService.SendAsync</c>);
/// this is the system-generated kind the spec also calls for, so it polls instead
/// of waiting on a request. Runs in pwm.Worker rather than pwm.WebAPI for the same
/// reason <see cref="ReportGenerationWorker"/> does - a BackgroundService inside
/// the API process would not qualify as its own process.
/// </summary>
public class MissedClockOutWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly MissedClockOutOptions _options;
    private readonly ILogger<MissedClockOutWorker> _logger;

    public MissedClockOutWorker(
        IServiceScopeFactory scopeFactory,
        MissedClockOutOptions options,
        ILogger<MissedClockOutWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _options = options;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(_options.PollIntervalMinutes));

        // Sweeps once immediately - a shift already overdue when the container
        // starts should not have to wait a full interval to be reported - then
        // again on every tick until cancelled.
        do
        {
            try
            {
                await SweepAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Missed clock-out sweep failed; will retry next poll.");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task SweepAsync(CancellationToken stoppingToken)
    {
        await using var scope = _scopeFactory.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<PWMDbContext>();

        var now = DateTime.UtcNow;
        var threshold = now.AddHours(-_options.ThresholdHours);

        // Only shifts this worker has not already flagged - once notified, a shift
        // is done being polled no matter how much longer it stays open.
        var overdue = await dbContext.WorkLogs
            .Include(w => w.User)
            .Where(w => w.ClockedOut == null
                && w.MissedClockOutNotifiedAt == null
                && w.ClockedIn <= threshold)
            .ToListAsync(stoppingToken);

        if (overdue.Count == 0)
        {
            return;
        }

        var recipientIds = await dbContext.Users
            .Where(u => u.IsActive && (u.UserType.Type == Roles.Admin || u.UserType.Type == Roles.ProjectManager))
            .Select(u => u.Id)
            .ToListAsync(stoppingToken);

        if (recipientIds.Count == 0)
        {
            // Nobody to warn this poll; the shifts are still marked below so the
            // sweep does not just repeat this same warning forever.
            _logger.LogWarning(
                "{Count} shift(s) crossed {Hours}h unclosed, but no active admin or project manager exists to warn.",
                overdue.Count, _options.ThresholdHours);
        }

        var typeId = await NotificationTypeRules.IdOfAsync(dbContext, NotificationTypeRules.MissedClockOut, stoppingToken);

        foreach (var workLog in overdue)
        {
            if (recipientIds.Count > 0)
            {
                var elapsedHours = (now - workLog.ClockedIn).TotalHours;
                var message =
                    $"{workLog.User.Name} {workLog.User.Surname} clocked in on " +
                    $"{SarajevoTime.FromUtc(workLog.ClockedIn):dd.MM.yyyy HH:mm} and still has not clocked out " +
                    $"({elapsedHours:F1} hours and counting). Please check up on them.";

                dbContext.Notifications.AddRange(recipientIds.Select(userId => new Notification
                {
                    UserId = userId,
                    NotificationTypeId = typeId,
                    Title = "Missed clock-out",
                    Message = message,
                    IsRead = false,
                    CreatedAt = now,
                }));
            }

            workLog.MissedClockOutNotifiedAt = now;
        }

        await dbContext.SaveChangesAsync(stoppingToken);

        _logger.LogInformation(
            "Missed clock-out sweep: flagged {ShiftCount} shift(s) to {RecipientCount} recipient(s).",
            overdue.Count, recipientIds.Count);
    }
}
