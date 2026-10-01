using Microsoft.AspNetCore.SignalR;
using pwm.Services.Messaging;

namespace pwm.WebAPI.Hubs
{
    /// <summary>The API's side of a notification push: straight to the accounts' connections.</summary>
    public sealed class HubNotificationPushPublisher : INotificationPushPublisher
    {
        private readonly IHubContext<NotificationHub> _hub;
        private readonly ILogger<HubNotificationPushPublisher> _logger;

        public HubNotificationPushPublisher(IHubContext<NotificationHub> hub, ILogger<HubNotificationPushPublisher> logger)
        {
            _hub = hub;
            _logger = logger;
        }

        public async Task PublishAsync(IReadOnlyCollection<int> userIds, CancellationToken cancellationToken = default)
        {
            try
            {
                await _hub.Clients
                    .Users(userIds.Select(id => id.ToString()).ToList())
                    .SendAsync(NotificationHub.NotificationsChanged, cancellationToken);
            }
            catch (Exception ex)
            {
                // The notifications are saved either way; a lost push only means
                // the app shows them on its next load instead of right away.
                _logger.LogWarning(ex, "Could not push a notification change to {Count} account(s).", userIds.Count);
            }
        }
    }
}
