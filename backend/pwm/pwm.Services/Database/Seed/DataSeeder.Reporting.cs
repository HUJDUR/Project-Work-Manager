using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using ReportKind = pwm.Model.Enums.ReportType;

namespace pwm.Services.Database.Seed
{
    public partial class DataSeeder
    {
        private async Task SeedMonthlyHourReportsAsync()
        {
            // One report per month covered by the seeded work logs
            var months = _workLogs
                .Select(log => new { log.ClockedIn.Year, log.ClockedIn.Month })
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
                        .Where(log => log.ClockedIn.Year == month.Year && log.ClockedIn.Month == month.Month)
                        .Sum(log => log.Hours), 2),
                })
                .ToArray();

            await AddRangeAsync(reports);

            var details = new List<MonthlyHourReportDetail>();

            foreach (var report in reports)
            {
                var perUser = _workLogs
                    .Where(log => log.ClockedIn.Year == report.Year && log.ClockedIn.Month == report.Month)
                    .GroupBy(log => log.UserId);

                foreach (var group in perUser)
                {
                    // Everything over eight hours on a date is overtime, so the split
                    // is worked out per day rather than over the month's total.
                    var regular = 0.0;
                    var overtime = 0.0;

                    foreach (var day in group.GroupBy(log => log.ClockedIn.Date))
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

        /// <summary>Mirrors <c>ReportService.RegularHoursPerDay</c>: over eight is overtime.</summary>
        private const double RegularHoursPerDay = 8;

        /// <summary>
        /// Who ran a report and when is not on the report row any more - it is the
        /// ActivityLog entry pointing at it, which <see cref="SeedActivityLogsAsync"/> writes.
        /// </summary>
        private readonly List<(GeneratedReport Report, int UserId, DateTime At)> _reportRuns = [];

        private async Task SeedGeneratedReportsAsync()
        {
            // A short history for the Reports screen's "Recent Reports" list. The PDFs
            // are not stored - each row is rebuilt from these parameters on download.
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
                ("Project ready for delivery", "Staircase module WM-45 has been loaded and is ready to leave."),
                ("New project created", "Silo foundations AK-88 was created for Adria Konstrukcije d.o.o."),
                ("Delivery date approaching", "Staircase module WM-45 is due for delivery in 3 days."),
                ("Truck load registered", "A load for Euro Spedicija d.o.o. was registered this morning."),
                ("Assigned to project", "You have been assigned welding work on Platform driptrays MU-2311."),
                ("Missing clock out", "Please check your work log, one shift was closed automatically."),
                ("Quality check requested", "Machine base plates AK-77 need a quality check before packing."),
                ("Shift change", "Next week the early shift starts at 06:00."),
                ("Monthly report generated", "The monthly hour report has been generated and is ready for review."),
                ("Material delivered", "The plate delivery for AK-77 has arrived at the yard."),
            };

            var notifications = new List<Notification>();

            for (var i = 0; i < 40; i++)
            {
                var (title, message) = messages[i % messages.Length];
                var hoursAgo = _random.Next(1, 72);

                var sentBy = Pick(office).Id;
                var createdAt = DateTime.UtcNow.AddHours(-hoursAgo);

                _messagesSent.Add((sentBy, createdAt));

                notifications.Add(new Notification
                {
                    UserId = Pick(recipients).Id,
                    Title = title,
                    Message = message,
                    IsRead = _random.Next(3) != 0,
                    CreatedAt = createdAt,
                });
            }

            _notifications = notifications.ToArray();
            await AddRangeAsync(_notifications);
        }

        private async Task SeedActivityLogsAsync()
        {
            var logs = new List<ActivityLog>();

            var login = FindLogType("Log In").Id;
            var logout = FindLogType("Log out").Id;
            var messageSent = FindLogType("Message sent").Id;
            var markedRead = FindLogType("Marked messages as read").Id;

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
                    Date = notification.CreatedAt.AddMinutes(_random.Next(5, 600)),
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
