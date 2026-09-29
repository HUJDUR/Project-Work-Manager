using pwm.Common.Services.Time;
using pwm.Model.Access;
using pwm.Model.Enums;
using pwm.Model.Requests;
using pwm.Services.Reporting;
using System.Text.Json;
using ReportKind = pwm.Model.Enums.ReportType;

namespace pwm.Services.Database.Seed
{
    public partial class DataSeeder
    {
        private async Task SeedMonthlyHourReportsAsync()
        {
            // One report per Sarajevo month covered by the seeded work logs (stored
            // in UTC by now, hence the conversion back).
            var months = _workLogs
                .Select(log => SarajevoTime.FromUtc(log.ClockedIn))
                .Select(clockedIn => new { clockedIn.Year, clockedIn.Month })
                .Distinct()
                .OrderBy(m => m.Year)
                .ThenBy(m => m.Month)
                .ToArray();

            var reports = months
                .Select(month => new MonthlyHourReport
                {
                    Year = month.Year,
                    Month = month.Month,
                    TotalHours = Math.Round(_workLogs
                        .Where(log => InMonth(log, month.Year, month.Month))
                        .Sum(log => log.Hours), 2),
                })
                .ToArray();

            await AddRangeAsync(reports);

            var details = new List<MonthlyHourReportDetail>();

            foreach (var report in reports)
            {
                var perUser = _workLogs
                    .Where(log => InMonth(log, report.Year, report.Month))
                    .GroupBy(log => log.UserId);

                foreach (var group in perUser)
                {
                    // Everything over eight hours on a date is overtime, so the split
                    // is worked out per day rather than over the month's total.
                    var regular = 0.0;
                    var overtime = 0.0;

                    foreach (var day in group.GroupBy(log => SarajevoTime.DayOf(log.ClockedIn)))
                    {
                        var hours = day.Sum(log => log.Hours);
                        var regularToday = Math.Min(hours, RegularHoursPerDay);

                        regular += regularToday;
                        overtime += hours - regularToday;
                    }

                    details.Add(new MonthlyHourReportDetail
                    {
                        MonthlyHourReportId = report.Id,
                        UserId = group.Key,
                        TotalHours = Math.Round(regular + overtime, 2),
                        RegularHours = Math.Round(regular, 2),
                        OvertimeHours = Math.Round(overtime, 2),
                    });
                }
            }

            await AddRangeAsync(details.ToArray());
        }

        private static bool InMonth(WorkLog log, int year, int month)
        {
            var clockedIn = SarajevoTime.FromUtc(log.ClockedIn);
            return clockedIn.Year == year && clockedIn.Month == month;
        }

        private const double RegularHoursPerDay = ReportBuilder.RegularHoursPerDay;

        /// <summary>
        /// Who ran a report and when is not on the report row any more - it is the
        /// ActivityLog entry pointing at it, which <see cref="SeedActivityLogsAsync"/> writes.
        /// </summary>
        private readonly List<(GeneratedReport Report, int UserId, DateTime At)> _reportRuns = [];

        private async Task SeedGeneratedReportsAsync()
        {
            // A short history for the Reports screen's "Recent Reports" list, rendered
            // here with the same ReportBuilder pwm.Worker uses - a seeded row is never
            // queued, so without its PDF it would sit at "Pending" forever.
            var lastMonth = _today.AddMonths(-1);

            _generatedReports =
            [
                new GeneratedReport
                {
                    ReportTypeId = (int)ReportKind.MonthlyWorkHours,
                    Parameters = $$"""{"Year":{{lastMonth.Year}},"Month":{{lastMonth.Month}},"UserId":null,"ProjectId":null}""",
                },
                new GeneratedReport
                {
                    ReportTypeId = (int)ReportKind.TransportLoads,
                    Parameters = """{"ProjectId":null,"DateFrom":null,"DateTo":null}""",
                },
                new GeneratedReport
                {
                    ReportTypeId = (int)ReportKind.MonthlyWorkHours,
                    Parameters = $$"""{"Year":{{_today.Year}},"Month":{{_today.Month}},"UserId":null,"ProjectId":null}""",
                },
            ];

            var builder = new ReportBuilder(_db);

            foreach (var report in _generatedReports)
            {
                report.Content = (ReportKind)report.ReportTypeId switch
                {
                    ReportKind.MonthlyWorkHours => await builder.BuildMonthlyWorkHoursAsync(
                        JsonSerializer.Deserialize<MonthlyWorkHoursReportRequest>(report.Parameters)!),
                    _ => await builder.BuildTransportLoadsAsync(
                        JsonSerializer.Deserialize<TransportLoadsReportRequest>(report.Parameters)!),
                };
                report.Status = ReportStatus.Completed;
            }

            await AddRangeAsync(_generatedReports);

            // Monthly hours is Admin or Finances; a project manager only runs transports.
            var runners = new[]
            {
                FindUser("nadira.stupar@pwm.ba").Id,
                FindUser("kenan.fajic@pwm.ba").Id,
                FindUser("nadir.hujdur@pwm.ba").Id,
            };

            var daysAgo = new[] { 21, 12, 3 };

            for (var i = 0; i < _generatedReports.Length; i++)
            {
                _reportRuns.Add((_generatedReports[i], runners[i], _today.AddDays(-daysAgo[i]).AddHours(10)));
            }
        }

        /// <summary>
        /// Notifications carry no sender column, so who sent one is only ever the
        /// "Message sent" activity log entry - kept here until those are written.
        /// </summary>
        private readonly List<(int SenderId, DateTime At)> _messagesSent = [];

        private async Task SeedNotificationsAsync()
        {
            var office = OfficeUsers;
            var recipients = _users.Where(u => u.IsActive).ToArray();

            var messages = new (string Title, string Message)[]
            {
                ("Project ready for delivery", "The staircase module has been loaded and is ready to leave."),
                ("New project created", "Silo foundations was created for Adria Konstrukcije d.o.o."),
                ("Delivery date approaching", "The staircase module is due for delivery in 3 days."),
                ("Truck load registered", "A load for Euro Spedicija d.o.o. was registered this morning."),
                ("Assigned to project", "You have been assigned welding work on the platform driptrays."),
                ("Missing clock out", "Please check your work log, one shift was closed automatically."),
                ("Quality check requested", "The machine base plates need a quality check before packing."),
                ("Shift change", "Next week the early shift starts at 06:00."),
                ("Monthly report generated", "The monthly hour report has been generated and is ready for review."),
                ("Material delivered", "The plate delivery for the machine base plates has arrived at the yard."),
            };

            var notifications = new List<Notification>();
            var nextMessage = 0;

            // Dealt out per recipient rather than by picking a recipient per
            // message: 40 messages scattered over the whole roster left a third
            // of the accounts with none at all, and the mobile Notifications tab
            // opening on an empty list cannot be told from a broken screen.
            // Everybody who still works gets a handful, and some more than a
            // page of them, so "Load more" is reachable.
            foreach (var recipient in recipients)
            {
                var count = _random.Next(3, 10);

                for (var i = 0; i < count; i++)
                {
                    var (title, message) = messages[nextMessage++ % messages.Length];
                    var hoursAgo = _random.Next(1, 72);

                    var sentBy = Pick(office).Id;
                    var createdAt = DateTime.UtcNow.AddHours(-hoursAgo);

                    _messagesSent.Add((sentBy, createdAt));

                    notifications.Add(new Notification
                    {
                        UserId = recipient.Id,
                        Title = title,
                        Message = message,
                        IsRead = _random.Next(3) != 0,
                        CreatedAt = createdAt,
                    });
                }
            }

            _notifications = notifications.ToArray();
            await AddRangeAsync(_notifications);
        }

        private static DateTime Min(DateTime a, DateTime b) => a < b ? a : b;

        private async Task SeedActivityLogsAsync()
        {
            var logs = new List<ActivityLog>();

            var login = FindLogType(ActivityLogTypeNames.LogIn).Id;
            var logout = FindLogType(ActivityLogTypeNames.LogOut).Id;
            var messageSent = FindLogType(ActivityLogTypeNames.MessageSent).Id;
            var markedRead = FindLogType(ActivityLogTypeNames.MarkedMessagesAsRead).Id;

            // A shift is a day on the shop floor, so it opens and closes a session
            foreach (var workLog in _workLogs)
            {
                logs.Add(new ActivityLog
                {
                    UserId = workLog.UserId,
                    ActivityLogTypeId = login,
                    Date = workLog.ClockedIn,
                });

                if (workLog.ClockedOut.HasValue)
                {
                    logs.Add(new ActivityLog
                    {
                        UserId = workLog.UserId,
                        ActivityLogTypeId = logout,
                        Date = workLog.ClockedOut.Value,
                    });
                }
            }

            // Plus the office sessions
            foreach (var day in WorkingDays(10))
            {
                foreach (var user in OfficeUsers)
                {
                    logs.Add(new ActivityLog { UserId = user.Id, ActivityLogTypeId = login, Date = day.AddHours(8) });
                    logs.Add(new ActivityLog { UserId = user.Id, ActivityLogTypeId = logout, Date = day.AddHours(16) });
                }
            }

            // One entry per message that went out
            foreach (var (senderId, at) in _messagesSent)
            {
                logs.Add(new ActivityLog
                {
                    UserId = senderId,
                    ActivityLogTypeId = messageSent,
                    Date = at,
                });
            }

            // ... and one per recipient who has read theirs
            foreach (var notification in _notifications.Where(x => x.IsRead))
            {
                logs.Add(new ActivityLog
                {
                    UserId = notification.UserId,
                    ActivityLogTypeId = markedRead,
                    // Read a little after it arrived - but never later than now.
                    Date = Min(notification.CreatedAt.AddMinutes(_random.Next(5, 600)), DateTime.UtcNow),
                });
            }

            // This is what records who generated a report and when
            foreach (var (report, userId, at) in _reportRuns)
            {
                var description = _reportTypes.First(x => x.Id == report.ReportTypeId).Description;

                logs.Add(new ActivityLog
                {
                    UserId = userId,
                    ActivityLogTypeId = FindLogType(ReportLogTypeName(description)).Id,
                    GeneratedReportId = report.Id,
                    Date = at,
                });
            }

            await AddRangeAsync(logs.ToArray());
        }
    }
}
