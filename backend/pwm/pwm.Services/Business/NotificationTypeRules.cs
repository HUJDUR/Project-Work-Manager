using Microsoft.EntityFrameworkCore;
using pwm.Model.Exceptions;
using pwm.Services.Database;

namespace pwm.Services.Business
{
    /// <summary>
    /// The seeded <see cref="NotificationType"/> names. The system ones are what code
    /// stamps on the notifications it raises itself; the others are where the office's
    /// own list of types starts.
    /// </summary>
    public static class NotificationTypeRules
    {
        public const string General = "General";
        public const string Reminder = "Reminder";
        public const string Safety = "Safety";
        public const string Schedule = "Schedule";

        public const string MissedClockOut = "Missed clock-out";
        public const string Absence = "Absence";
        public const string WorkHoursChange = "Work hours change";
        public const string ProjectStatus = "Project status";
        public const string TransportStatus = "Transport status";
        public const string PasswordReset = "Password reset";

        public static readonly string[] Manual = [General, Reminder, Safety, Schedule];

        public static readonly string[] System =
            [MissedClockOut, Absence, WorkHoursChange, ProjectStatus, TransportStatus, PasswordReset];

        /// <summary>The id of the type named <paramref name="name"/>.</summary>
        public static async Task<int> IdOfAsync(PWMDbContext db, string name, CancellationToken cancellationToken = default) =>
            await db.NotificationTypes
                .Where(x => x.Name == name)
                .Select(x => (int?)x.Id)
                .FirstOrDefaultAsync(cancellationToken)
            ?? throw new InvalidOperationException(
                $"The \"{name}\" notification type is missing - reseed the lookup tables.");

        /// <summary>A notification sent by hand has to be of a type the office sends.</summary>
        public static async Task EnsureSendableAsync(PWMDbContext db, int notificationTypeId)
        {
            var type = await db.NotificationTypes
                    .Where(x => x.Id == notificationTypeId)
                    .Select(x => new { x.Name, x.IsSystem })
                    .FirstOrDefaultAsync()
                ?? throw new ClientException("That notification type does not exist.");

            if (type.IsSystem)
            {
                throw new ClientException(
                    $"\"{type.Name}\" notifications are raised by the system - pick another type.");
            }
        }
    }
}
