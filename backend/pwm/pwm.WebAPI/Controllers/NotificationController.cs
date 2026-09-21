using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>No update or delete - a sent notification is immutable.</summary>
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
            var senderId = _currentUser.Id
                ?? throw new ForbiddenException("The token carries no user, so there is nothing to send this as.");

            return await _notifications.SendAsync(senderId, request);
        }

        /// <summary>Open to every role - rows are scoped to the caller via the token, not an id.</summary>
        [HttpPost("MarkRead")]
        [Authorization(Roles.Admin, Roles.WorkPreparation, Roles.Finances, Roles.ProjectManager, Roles.ProductionWorker)]
        public async Task<NotificationMarkReadResponse> MarkRead([FromBody] NotificationMarkReadRequest request)
        {
            var userId = _currentUser.Id
                ?? throw new ForbiddenException("The token carries no user, so there is nothing to mark read.");

            return await _notifications.MarkReadAsync(userId, request);
        }
    }
}
