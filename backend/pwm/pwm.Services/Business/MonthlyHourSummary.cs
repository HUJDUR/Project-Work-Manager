using Microsoft.EntityFrameworkCore;
using pwm.Common.Services.Time;
using pwm.Services.Database;

namespace pwm.Services.Business
{
    /// <summary>
    /// Keeps <see cref="MonthlyHourReport"/> and its <see cref="MonthlyHourReportDetail"/>
    /// rows - the monthly payroll summary behind the Monthly Reports screen - true to
    /// the work actually booked. Every write that changes a block of work (clocking in
    /// or out, an office correction, a deleted shift) recalculates the months it
    /// touched, in the same transaction as the write, so the summary is never stale.
    /// </summary>
    public static class MonthlyHourSummary
    {
        /// <summary>The Sarajevo month a moment falls in.</summary>
        public static (int Year, int Month) MonthOf(DateTime utc)
        {
            var local = SarajevoTime.FromUtc(utc);
            return (local.Year, local.Month);
        }

        /// <summary>
        /// Saves the caller's changes and brings the given months' summaries up to date,
        /// both or neither: the summary is worked out from the saved blocks, so it takes
        /// a second save - inside one explicit transaction.
        /// </summary>
        public static async Task SaveAndRecalculateAsync(PWMDbContext db, IEnumerable<DateTime> touched)
        {
            var months = touched.Select(MonthOf).Distinct().ToList();

            if (db.Database.CurrentTransaction is not null)
            {
                await db.SaveChangesAsync();
                await RecalculateAndSaveAsync(db, months);
                return;
            }

            await using var transaction = await db.Database.BeginTransactionAsync();
            await db.SaveChangesAsync();
            await RecalculateAndSaveAsync(db, months);
            await transaction.CommitAsync();
        }

        public static async Task RecalculateAndSaveAsync(PWMDbContext db, IEnumerable<(int Year, int Month)> months)
        {
            foreach (var (year, month) in months)
            {
                await RecalculateAsync(db, year, month);
            }

            await db.SaveChangesAsync();
        }

        /// <summary>
        /// One month, from its blocks of work: each block's regular part, per worker
        /// the regular and overtime hours (see <see cref="OvertimeRules"/>) and the
        /// days they worked, and the month's totals. Staged, not saved. A month with
        /// no work left has no summary.
        /// </summary>
        private static async Task RecalculateAsync(PWMDbContext db, int year, int month)
        {
            var first = new DateTime(year, month, 1);
            var from = SarajevoTime.StartOfDayUtc(first);
            var to = SarajevoTime.StartOfDayUtc(first.AddMonths(1));

            // Tracked, not projected: each block's own RegularHours is written back.
            // A Sarajevo day never spans two months, so the month holds every block
            // the overtime rule needs.
            var blocks = await db.WorkLogDetails
                .Where(x => x.StartedAt >= from && x.StartedAt < to)
                .ToListAsync();

            var report = await db.MonthlyHourReports.FirstOrDefaultAsync(x => x.Year == year && x.Month == month);
            var existing = report is null
                ? []
                : await db.MonthlyHourReportDetails.Where(x => x.MonthlyHourReportId == report.Id).ToListAsync();

            if (blocks.Count == 0)
            {
                if (report is not null)
                {
                    db.MonthlyHourReportDetails.RemoveRange(existing);
                    db.MonthlyHourReports.Remove(report);
                }

                return;
            }

            if (report is null)
            {
                report = new MonthlyHourReport { Year = year, Month = month };
                db.MonthlyHourReports.Add(report);
            }

            var regularById = OvertimeRules.RegularHours(blocks.Select(x => (x.Id, x.UserId, x.StartedAt, x.Hours)));
            foreach (var block in blocks)
            {
                block.RegularHours = Math.Round(regularById[block.Id], 2);
            }

            var workers = blocks
                .GroupBy(x => x.UserId)
                .Select(worker =>
                {
                    var total = worker.Sum(x => x.Hours);
                    var regular = worker.Sum(x => x.RegularHours);
                    return new
                    {
                        UserId = worker.Key,
                        Total = Math.Round(total, 2),
                        Regular = Math.Round(regular, 2),
                        Overtime = Math.Round(total - regular, 2),
                        Days = worker.Select(x => SarajevoTime.DayOf(x.StartedAt)).Distinct().Count(),
                    };
                })
                .ToList();

            foreach (var worker in workers)
            {
                var detail = existing.FirstOrDefault(x => x.UserId == worker.UserId);
                if (detail is null)
                {
                    detail = new MonthlyHourReportDetail { MonthlyHourReport = report, UserId = worker.UserId };
                    db.MonthlyHourReportDetails.Add(detail);
                }

                detail.TotalHours = worker.Total;
                detail.RegularHours = worker.Regular;
                detail.OvertimeHours = worker.Overtime;
                detail.DaysWorked = worker.Days;
            }

            var gone = workers.Select(x => x.UserId).ToHashSet();
            db.MonthlyHourReportDetails.RemoveRange(existing.Where(x => !gone.Contains(x.UserId)));

            report.TotalHours = Math.Round(workers.Sum(x => x.Total), 2);
            report.RegularHours = Math.Round(workers.Sum(x => x.Regular), 2);
            report.OvertimeHours = Math.Round(workers.Sum(x => x.Overtime), 2);
            report.WorkerCount = workers.Count;
        }
    }
}
