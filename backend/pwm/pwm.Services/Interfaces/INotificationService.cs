using System.Threading.Tasks;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;

namespace pwm.Services.Interfaces
{
    public interface INotificationService : IBaseReadService<NotificationResponse, NotificationSearchObject>
    {
        /// <summary>
        /// Writes one notification per recipient and answers how many that was.
        /// The only door into the table other than the seeder.
        /// </summary>
        Task<NotificationSendResponse> SendAsync(NotificationSendRequest request);
    }
}
