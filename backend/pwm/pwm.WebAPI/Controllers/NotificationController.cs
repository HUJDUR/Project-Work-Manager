using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;
using pwm.WebAPI.Services.CurrentUser;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Reading is the generic list and get-by-id. Writing is two narrow endpoints
    /// and nothing else: the office sends a message with <c>Send</c>, and a reader
    /// marks their own copies read with <c>MarkRead</c>. There is still no update
    /// or delete - a notification that was sent stays sent, and its text stays
    /// what it was.
    /// </summary>
    public class NotificationController : BaseReadController<NotificationResponse, NotificationSearchObject>
    {
        private readonly INotificationService _notifications;
        private readonly ICurrentUser _currentUser;

        public NotificationController(INotificationService service, ICurrentUser currentUser) : base(service)
        {
            _notifications = service;
            _currentUser = currentUser;
        }

        [HttpPost("Send")]
        [Authorization(Roles.Admin, Roles.WorkPreparation, Roles.Finances, Roles.ProjectManager)]
        public async Task<NotificationSendResponse> Send([FromBody] NotificationSendRequest request)
        {
            return await _notifications.SendAsync(request);
        }

        /// <summary>
        /// Every role, including the shop floor: this is the one write anybody may
        /// make, and it reaches only their own rows. Which rows those are is
        /// decided by the token, so there is no id in the route or the body to
        /// point at another account.
        /// </summary>
        [HttpPost("MarkRead")]
        [Authorization(Roles.Admin, Roles.WorkPreparation, Roles.Finances, Roles.ProjectManager, Roles.ProductionWorker)]
        public async Task<NotificationMarkReadResponse> MarkRead([FromBody] NotificationMarkReadRequest request)
        {
            // Unlike the work log controllers there is no owner to fall back to:
            // "mark mine read" has no meaning without a caller, so a token with no
            // user is refused rather than quietly widened.
            var userId = _currentUser.Id
                ?? throw new ForbiddenException("The token carries no user, so there is nothing to mark read.");

            return await _notifications.MarkReadAsync(userId, request);
        }
    }
}
