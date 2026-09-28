using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services.Interfaces
{
    public interface INotificationService : IBaseReadService<NotificationResponse, NotificationSearchObject>
    {
        /// <summary>
        /// Writes one notification per recipient and answers how many that was.
        /// The only way a row gets into the table other than the seeder.
        /// <paramref name="senderId"/> comes from the token, never the request body - a
        /// notification carries no sender column of its own, so the "Message sent"
        /// activity log entry this also writes is the only record of who sent it.
        /// </summary>
        Task<NotificationSendResponse> SendAsync(int senderId, NotificationSendRequest request);

        /// <summary>
        /// Flips <c>IsRead</c> on the caller's own notifications and answers how
        /// many that changed. The other door into the table, and the reason the
        /// column is worth having.
        /// </summary>
        Task<NotificationMarkReadResponse> MarkReadAsync(int userId, NotificationMarkReadRequest request);

        /// <summary>
        /// The third door into the table, and the only one with no signed-in sender:
        /// "Reset password" on the login screen, for someone who cannot reach any
        /// other part of the app. Writes one notification straight to every active
        /// Admin account, naming whoever asked - unlike <see cref="SendAsync"/> there
        /// is no <c>NotificationSendRequest</c> to fan out and no "Message sent" log
        /// entry, since nobody signed in sent this.
        /// </summary>
        Task NotifyAdminsOfPasswordResetRequestAsync(int requesterId, string requesterName, string requesterEmail);
    }
}
