using System.Globalization;
using Microsoft.EntityFrameworkCore;
using pwm.Common.Services.Time;
using pwm.Model.Access;
using pwm.Services.Database;

namespace pwm.Worker;

/// <summary>
/// "Which workers are not at work today": on every weekday, once the configured
/// time has passed (07:30 by default, Sarajevo time), the admins and project
/// managers get one notification listing the active production workers who have
/// not clocked in yet. Nothing is sent when everybody is in.
///
/// Sent once a day and never twice: a restart later in the morning finds today's
/// list already sent and leaves it, and one that starts after the time still
/// sends it, rather than skipping the day. It knows nothing of holidays or leave -
/// the app has no record of either - so on those days the list says so plainly.
/// </summary>
public class AbsenceCheckWorker : BackgroundService
{
    public const string Title = "Not at work today";

    private const int MaxNamesListed = 40;

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly TimeSpan _checkAt;
    private readonly ILogger<AbsenceCheckWorker> _logger;

    /// <summary>The Sarajevo day already dealt with, so each minute's tick is cheap.</summary>
    private DateTime? _doneFor;

    public AbsenceCheckWorker(
        IServiceScopeFactory scopeFactory,
        AbsenceCheckOptions options,
        ILogger<AbsenceCheckWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _checkAt = TimeSpan.ParseExact(options.TimeOfDay, @"hh\:mm", CultureInfo.InvariantCulture);
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));

        do
        {
            try
            {
                await CheckAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Absence check failed; will retry next minute.");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task CheckAsync(CancellationToken stoppingToken)
    {
        var now = SarajevoTime.Now;
        var today = now.Date;

        if (_doneFor == today)
        {
            return;
        }

        if (today.DayOfWeek is DayOfWeek.Saturday or DayOfWeek.Sunday)
        {
            _doneFor = today;
            return;
        }

        if (now.TimeOfDay < _checkAt)
        {
            return;
        }

        await using var scope = _scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<PWMDbContext>();

        var dayStart = SarajevoTime.StartOfDayUtc(today);
        var dayEnd = SarajevoTime.StartOfDayUtc(today.AddDays(1));

        var alreadySent = await db.Notifications
            .AnyAsync(x => x.Title == Title && x.CreatedAt >= dayStart && x.CreatedAt < dayEnd, stoppingToken);

        if (!alreadySent)
        {
            await SendAsync(db, now, dayStart, dayEnd, stoppingToken);
        }

        _doneFor = today;
    }

    private async Task SendAsync(
        PWMDbContext db, DateTime now, DateTime dayStart, DateTime dayEnd, CancellationToken stoppingToken)
    {
        var absent = await db.Users
            .Where(u => u.IsActive && u.UserType.Type == Roles.ProductionWorker)
            .Where(u => !db.WorkLogs.Any(w => w.UserId == u.Id && w.ClockedIn >= dayStart && w.ClockedIn < dayEnd))
            .OrderBy(u => u.Surname).ThenBy(u => u.Name)
            .Select(u => (u.Name + " " + u.Surname).Trim())
            .ToListAsync(stoppingToken);

        if (absent.Count == 0)
        {
            _logger.LogInformation("Absence check: every active worker has clocked in.");
            return;
        }

        var recipientIds = await db.Users
            .Where(u => u.IsActive && (u.UserType.Type == Roles.Admin || u.UserType.Type == Roles.ProjectManager))
            .Select(u => u.Id)
            .ToListAsync(stoppingToken);

        if (recipientIds.Count == 0)
        {
            _logger.LogWarning(
                "Absence check: {Count} worker(s) have not clocked in, but no active admin or project manager exists to tell.",
                absent.Count);
            return;
        }

        var names = string.Join(", ", absent.Take(MaxNamesListed));
        if (absent.Count > MaxNamesListed)
        {
            names += $" and {absent.Count - MaxNamesListed} more";
        }

        var message = absent.Count == 1
            ? $"1 worker had not clocked in by {now:HH:mm} on {now:dd.MM.yyyy}: {names}."
            : $"{absent.Count} workers had not clocked in by {now:HH:mm} on {now:dd.MM.yyyy}: {names}.";

        var sentAt = DateTime.UtcNow;
        db.Notifications.AddRange(recipientIds.Select(userId => new Notification
        {
            UserId = userId,
            Title = Title,
            Message = message,
            IsRead = false,
            CreatedAt = sentAt,
        }));

        // Pushed to the apps by NotificationPushInterceptor, via the API.
        await db.SaveChangesAsync(stoppingToken);

        _logger.LogInformation(
            "Absence check: {Count} worker(s) not in yet, sent to {Recipients} recipient(s).",
            absent.Count, recipientIds.Count);
    }
}
