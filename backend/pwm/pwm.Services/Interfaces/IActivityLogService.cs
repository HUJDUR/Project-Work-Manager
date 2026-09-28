using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services.Interfaces
{
    public interface IActivityLogService : IBaseReadService<ActivityLogResponse, ActivityLogSearchObject>
    {
        /// <summary>
        /// Tracks one <c>ActivityLog</c> row for an event that just happened, on the same
        /// <c>DbContext</c> the caller already holds - it does not call <c>SaveChangesAsync</c>
        /// itself. That is deliberate: a service calling another service that commits on its
        /// own is exactly the pattern the coding standard forbids, so the caller's own save
        /// (whatever else it is doing in the same operation) is what actually persists this
        /// row, atomically with the rest. The name has to match one of the fixed rows in
        /// <c>ActivityLogTypes</c> exactly - see <c>DataSeeder.Lookups.SeedLookupsAsync</c> for
        /// where those names come from, and <c>ActivityLogTypeNames</c> for the constants
        /// callers should pass instead of a literal string. Silently does nothing if the name
        /// matches no row - the event that triggered this must not fail just because the log of
        /// it could not be written (e.g. a database wiped down to a single account for testing).
        /// </summary>
        Task RecordAsync(int userId, string activityLogTypeName);
    }
}
