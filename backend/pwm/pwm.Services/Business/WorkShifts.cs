using Microsoft.EntityFrameworkCore;
using pwm.Common.Services.Time;
using pwm.Services.Database;

namespace pwm.Services.Business
{
    /// <summary>
    /// A shift (<see cref="WorkLog"/>) is one worker's Sarajevo day and nothing more
    /// than the sum of its blocks of work. Its start, end and hours are worked out
    /// here from those blocks after every write that touches them - never taken from
    /// a request - and a shift left without a block is removed, so an empty shift can
    /// never pass for a day at work.
    /// </summary>
    public static class WorkShifts
    {
        /// <summary>
        /// The worker's shift for the Sarajevo day <paramref name="startedAt"/> falls
        /// on - staged as a new one when the day has none yet.
        /// </summary>
        public static async Task<WorkLog> ForDayAsync(PWMDbContext db, int userId, DateTime startedAt)
        {
            var day = SarajevoTime.DayOf(startedAt);
            var dayStart = SarajevoTime.StartOfDayUtc(day);
            var dayEnd = SarajevoTime.StartOfDayUtc(day.AddDays(1));

            var shift = await db.WorkLogs
                .Where(x => x.UserId == userId && x.ClockedIn >= dayStart && x.ClockedIn < dayEnd)
                .OrderBy(x => x.ClockedIn)
                .FirstOrDefaultAsync();

            if (shift is null)
            {
                shift = new WorkLog { UserId = userId, ClockedIn = startedAt };
                db.WorkLogs.Add(shift);
            }

            return shift;
        }

        /// <summary>
        /// Brings the shift in line with its blocks as this unit of work leaves them -
        /// the saved ones with their pending edits, the added ones, without the removed
        /// ones or those moved to another shift: the earliest start, the latest finish
        /// (none while a block is still running) and the hours added up. Removes the
        /// shift when no block is left. Staged, not saved.
        /// </summary>
        public static async Task RecalculateAsync(PWMDbContext db, WorkLog shift)
        {
            // Moves first, so a block reassigned to another shift is not counted here.
            db.ChangeTracker.DetectChanges();

            if (db.Entry(shift).State != EntityState.Added)
            {
                await db.WorkLogDetails.Where(x => x.WorkLogId == shift.Id).LoadAsync();
            }

            var blocks = db.WorkLogDetails.Local.Where(x => x.WorkLog == shift).ToList();

            if (blocks.Count == 0)
            {
                db.WorkLogs.Remove(shift);
                return;
            }

            shift.ClockedIn = blocks.Min(x => x.StartedAt);
            shift.ClockedOut = blocks.Any(x => x.FinishedAt == null) ? null : blocks.Max(x => x.FinishedAt);
            shift.Hours = Math.Round(blocks.Sum(x => x.Hours), 2);
        }
    }
}
