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
        /// </summary>
        Task<NotificationSendResponse> SendAsync(NotificationSendRequest request);

        /// <summary>
        /// Flips <c>IsRead</c> on the caller's own notifications and answers how
        /// many that changed. The other door into the table, and the reason the
        /// column is worth having.
        /// </summary>
        Task<NotificationMarkReadResponse> MarkReadAsync(int userId, NotificationMarkReadRequest request);
    }
}
