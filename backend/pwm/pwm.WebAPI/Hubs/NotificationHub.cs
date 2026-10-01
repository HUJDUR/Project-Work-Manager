using Microsoft.AspNetCore.SignalR;
using pwm.WebAPI.Services.AccessManager;

namespace pwm.WebAPI.Hubs
{
    /// <summary>
    /// The live half of notifications (§7.2): the desktop and mobile apps hold a
    /// connection here while signed in, and <see cref="NotificationsChanged"/> tells
    /// an account's own connections to reload. Nothing is sent over it but that
    /// signal - the notifications themselves are still read through the API, with
    /// its usual scoping. Signed-in only, like every other endpoint (the fallback
    /// policy), with the token passed as <c>access_token</c> on the query string -
    /// see <c>Program.cs</c>.
    /// </summary>
    public class NotificationHub : Hub
    {
        public const string Path = "/hubs/notifications";

        /// <summary>The one message clients listen for.</summary>
        public const string NotificationsChanged = "notificationsChanged";
    }

    /// <summary>
    /// SignalR addresses users by <see cref="HubConnectionContext.UserIdentifier"/>,
    /// which by default comes from a claim this API does not issue - this makes it
    /// the account id the token does carry.
    /// </summary>
    public class AccountIdUserIdProvider : IUserIdProvider
    {
        public string? GetUserId(HubConnectionContext connection) =>
            connection.User?.FindFirst(ClaimNames.Id)?.Value;
    }
}
