using Microsoft.EntityFrameworkCore;
using pwm.Common.Services.Time;
using pwm.Model.Exceptions;
using pwm.Services.Database;

namespace pwm.Services.Business
{
    /// <summary>
    /// What every booking of work has to satisfy, whoever books it - a worker
    /// clocking in on the phone or the office correcting hours on the desktop.
    /// Checked on the server, against the database, never left to the client.
    /// </summary>
    public static class WorkBookingRules
    {
        /// <summary>No single block of work, and no shift, runs longer than a day.</summary>
        public const double MaxHours = 24;

        /// <summary>The longest note a block of work may carry.</summary>
        public const int NoteMaxLength = 200;

        public static readonly string NoteTooLong = $"Keep the note to {NoteMaxLength} characters or fewer.";

        /// <summary>A note as it is stored: trimmed, and none at all when blank.</summary>
        public static string? CleanNote(string? note) => string.IsNullOrWhiteSpace(note) ? null : note.Trim();

        /// <summary>For a note that does not arrive through a validated request - clocking in.</summary>
        public static void EnsureNoteFits(string? note)
        {
            if (CleanNote(note)?.Length > NoteMaxLength)
            {
                throw new ClientException(NoteTooLong);
            }
        }

        /// <summary>Hours between two moments, to two places - what a block is paid for.</summary>
        public static double HoursBetween(DateTime start, DateTime end) =>
            Math.Round((end - start).TotalHours, 2);

        /// <summary>
        /// A project not actively worked (On hold, Delivered, Rejected) takes no new
        /// hours at all; one still only being quoted (Potential) takes only office
        /// hours - the shop floor has not been told to start yet. See
        /// <see cref="ProjectStatusRules"/>.
        /// </summary>
        public static async Task EnsureProjectAllowsBookingAsync(PWMDbContext db, int projectId, int operationTypeId)
        {
            var project = await db.Projects
                    .Include(x => x.ProjectStatus)
                    .FirstOrDefaultAsync(x => x.Id == projectId)
                ?? throw new NotFoundException($"Project with id {projectId} not found.");

            if (!ProjectStatusRules.CanBookAnything(project.ProjectStatus.Name))
            {
                throw new ClientException(
                    $"A \"{project.ProjectStatus.Name}\" project cannot have new hours booked against it.");
            }

            if (!ProjectStatusRules.RequiresOfficeOperationOnly(project.ProjectStatus.Name))
            {
                return;
            }

            var operationName = await db.OperationTypes
                    .Where(x => x.Id == operationTypeId)
                    .Select(x => x.Name)
                    .FirstOrDefaultAsync()
                ?? throw new NotFoundException($"OperationType with id {operationTypeId} not found.");

            if (!ProjectStatusRules.IsOfficeOperation(operationName))
            {
                throw new ClientException(
                    "A project still being quoted only takes office hours - Office work or Technical preparation.");
            }
        }

        /// <summary>Only an operation the worker is qualified for (their UserOperations).</summary>
        public static async Task EnsureQualifiedAsync(PWMDbContext db, int userId, int operationTypeId)
        {
            var qualified = await db.UserOperations
                .AnyAsync(x => x.UserId == userId && x.OperationTypeId == operationTypeId);

            if (!qualified)
            {
                throw new ClientException("That worker is not qualified for this operation.");
            }
        }

        /// <summary>
        /// Nobody works two things at once: the new block may not overlap any other
        /// block of the same person. A block still running (no finish yet) counts as
        /// running until it is closed - which is also what stops a second clock-in
        /// on top of an open session.
        /// </summary>
        public static async Task EnsureNoOverlapAsync(
            PWMDbContext db, int userId, DateTime start, DateTime? end, int? exceptBlockId)
        {
            var clash = await db.WorkLogDetails
                .Where(x => x.UserId == userId && (exceptBlockId == null || x.Id != exceptBlockId))
                .Where(x => (end == null || x.StartedAt < end) && (x.FinishedAt == null || x.FinishedAt > start))
                .OrderBy(x => x.StartedAt)
                .Select(x => new { x.StartedAt, x.FinishedAt })
                .FirstOrDefaultAsync();

            if (clash is null)
            {
                return;
            }

            throw new ClientException(clash.FinishedAt is { } finished
                ? $"This overlaps work already booked from {Format(clash.StartedAt)} to {Format(finished)}."
                : $"Already clocked in since {Format(clash.StartedAt)} - that session has to be closed first.");
        }

        private static string Format(DateTime utc) => SarajevoTime.FromUtc(utc).ToString("dd.MM.yyyy HH:mm");
    }
}
