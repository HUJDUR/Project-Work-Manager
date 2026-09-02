using Microsoft.AspNetCore.Mvc;
using pwm.Model.Access;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Interfaces;
using pwm.WebAPI.Filters;

namespace pwm.WebAPI.Controllers
{
    /// <summary>
    /// Reading is the generic list and get-by-id. Writing is the one endpoint the
    /// Send Notification screen posts to - the table stays otherwise closed, so a
    /// notification cannot be edited or deleted from outside.
    /// </summary>
    public class NotificationController : BaseReadController<NotificationResponse, NotificationSearchObject>
    {
        private readonly INotificationService _notifications;

        public NotificationController(INotificationService service) : base(service)
        {
            _notifications = service;
        }

        [HttpPost("Send")]
        [Authorization(Roles.Administrator, Roles.Manager)]
        public async Task<NotificationSendResponse> Send([FromBody] NotificationSendRequest request)
        {
            return await _notifications.SendAsync(request);
        }
    }
}
