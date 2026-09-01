using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using pwm.Model.Enums;

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

        private async Task SeedGeneratedReportsAsync()
        {
            // A short history for the Reports screen's "Recent Reports" list. The PDFs
            // are not stored - each row is rebuilt from these parameters on download.
            var admin = FindUser("admin@pwm.ba").Id;
            var manager = FindUser("amar.begic@pwm.ba").Id;
            var lastMonth = _today.AddMonths(-1);

            var reports = new[]
            {
                CreateGeneratedReport(ReportType.MonthlyWorkHours, admin, daysAgo: 21,
                    parameters: $$"""{"Year":{{lastMonth.Year}},"Month":{{lastMonth.Month}},"UserId":null,"ProjectId":null}"""),

                CreateGeneratedReport(ReportType.TransportLoads, manager, daysAgo: 12,
                    parameters: """{"ProjectId":null,"DateFrom":null,"DateTo":null}"""),

                CreateGeneratedReport(ReportType.MonthlyWorkHours, manager, daysAgo: 3,
                    parameters: $$"""{"Year":{{_today.Year}},"Month":{{_today.Month}},"UserId":null,"ProjectId":null}"""),
            };

            await AddRangeAsync(reports);
        }

        private GeneratedReport CreateGeneratedReport(
            ReportType type, int generatedById, int daysAgo, string parameters)
        {
            return new GeneratedReport
            {
                Type = type,
                Parameters = parameters,
                GeneratedAt = _today.AddDays(-daysAgo).AddHours(10),
                GeneratedById = generatedById,
            };
        }

        private async Task SeedNotificationsAsync()
        {
            var notifications = new[]
            {
                CreateNotification("amar.begic@pwm.ba", "Project ready for delivery",
                    "Staircase module WM-45 has been moved to Ready for delivery.", hoursAgo: 30, isRead: true),

                CreateNotification("amar.begic@pwm.ba", "New project created",
                    "Silo segments AK-88 was created for Adria Konstrukcije d.o.o.", hoursAgo: 20, isRead: false),

                CreateNotification("selma.delic@pwm.ba", "Delivery date approaching",
                    "Staircase module WM-45 is due for delivery in 3 days.", hoursAgo: 14, isRead: false),

                CreateNotification("selma.delic@pwm.ba", "Truck load registered",
                    "A load for Euro Spedicija d.o.o. was registered this morning.", hoursAgo: 6, isRead: false),

                CreateNotification("emir.kovacevic@pwm.ba", "Assigned to project",
                    "You have been assigned welding work on Platform railing MU-2311.", hoursAgo: 48, isRead: true),

                CreateNotification("emir.kovacevic@pwm.ba", "Missing clock out",
                    "Please check your work log, one shift was closed automatically.", hoursAgo: 26, isRead: false),

                CreateNotification("damir.softic@pwm.ba", "Assigned to project",
                    "Cutting work on Support brackets NM-204 is waiting for you.", hoursAgo: 22, isRead: false),

                CreateNotification("lejla.hodzic@pwm.ba", "Quality check requested",
                    "Machine base plates AK-77 need a quality check before packing.", hoursAgo: 9, isRead: false),

                CreateNotification("admin@pwm.ba", "Monthly report generated",
                    "The monthly hour report has been generated and is ready for review.", hoursAgo: 3, isRead: false),
            };

            await AddRangeAsync(notifications);
        }

        private Notification CreateNotification(string email, string title, string message, int hoursAgo, bool isRead)
        {
            return new Notification
            {
                UserId = FindUser(email).Id,
                Title = title,
                Message = message,
                IsRead = isRead,
                CreatedAt = DateTime.UtcNow.AddHours(-hoursAgo),
            };
        }

        private async Task SeedActivityLogsAsync()
        {
            var logs = new List<ActivityLog>();

            var login = FindLogType("Login").Id;
            var logout = FindLogType("Logout").Id;
            var clockIn = FindLogType("Clock in").Id;
            var clockOut = FindLogType("Clock out").Id;

            // Every seeded shift leaves a clock in / clock out trail
            foreach (var workLog in _workLogs)
            {
                logs.Add(new ActivityLog
                {
                    UserId = workLog.UserId,
                    ActivityLogTypeId = clockIn,
                    Date = workLog.ClockedIn,
                });

                if (workLog.ClockedOut.HasValue)
                {
                    logs.Add(new ActivityLog
                    {
                        UserId = workLog.UserId,
                        ActivityLogTypeId = clockOut,
                        Date = workLog.ClockedOut.Value,
                    });
                }
            }

            // Plus a few office sessions
            var officeUsers = new[] { "admin@pwm.ba", "amar.begic@pwm.ba", "selma.delic@pwm.ba" };

            foreach (var day in WorkingDays(10))
            {
                foreach (var email in officeUsers)
                {
                    var userId = FindUser(email).Id;

                    logs.Add(new ActivityLog { UserId = userId, ActivityLogTypeId = login, Date = day.AddHours(8) });
                    logs.Add(new ActivityLog { UserId = userId, ActivityLogTypeId = logout, Date = day.AddHours(16) });
                }
            }

            logs.Add(new ActivityLog
            {
                UserId = FindUser("selma.delic@pwm.ba").Id,
                ActivityLogTypeId = FindLogType("Project created").Id,
                Date = _today.AddDays(-4).AddHours(8),
            });

            logs.Add(new ActivityLog
            {
                UserId = FindUser("amar.begic@pwm.ba").Id,
                ActivityLogTypeId = FindLogType("Project status changed").Id,
                Date = _today.AddDays(-2).AddHours(11),
            });

            logs.Add(new ActivityLog
            {
                UserId = FindUser("selma.delic@pwm.ba").Id,
                ActivityLogTypeId = FindLogType("Truck load created").Id,
                Date = _today.AddHours(9),
            });

            logs.Add(new ActivityLog
            {
                UserId = FindUser("admin@pwm.ba").Id,
                ActivityLogTypeId = FindLogType("Report generated").Id,
                Date = _today.AddHours(7),
            });

            await AddRangeAsync(logs.ToArray());
        }
    }
}
