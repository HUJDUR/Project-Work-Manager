using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services.Interfaces
{
    public interface IActivityLogService : IBaseReadService<ActivityLogResponse, ActivityLogSearchObject>
    {
        /// <summary>
        /// Writes one <c>ActivityLog</c> row for an event that just happened. The name has
        /// to match one of the fixed rows in <c>ActivityLogTypes</c> exactly - see
        /// <c>DataSeeder.Lookups.SeedLookupsAsync</c> for where those names come from, and
        /// <c>ActivityLogTypeNames</c> for the constants callers should pass instead of a
        /// literal string. Silently does nothing if the name matches no row - the event that
        /// triggered this must not fail just because the log of it could not be written
        /// (e.g. a database wiped down to a single account for testing).
        /// </summary>
        Task RecordAsync(int userId, string activityLogTypeName);
    }
}
