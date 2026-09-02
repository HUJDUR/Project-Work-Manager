using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using FluentValidation;
using MapsterMapper;
using pwm.Model.Exceptions;
using pwm.Model.Requests;
using pwm.Model.Responses;
using pwm.Model.SearchObjects;
using pwm.Services.Database;
using pwm.Services.Interfaces;

namespace pwm.Services.Implementations
{
    public class NotificationService
        : BaseReadService<Notification, NotificationResponse, NotificationSearchObject>, INotificationService
    {
        private readonly IValidator<NotificationSendRequest> _sendValidator;

        public NotificationService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<NotificationSendRequest> sendValidator)
            : base(mapper, dbContext)
        {
            _sendValidator = sendValidator;
        }

        protected override IEnumerable<Notification> ApplyFilters(IEnumerable<Notification> query, NotificationSearchObject? search)
        {
            if (search == null)
            {
                return query;
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (search.IsRead.HasValue)
            {
                query = query.Where(x => x.IsRead == search.IsRead.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.Title))
            {
                var title = search.Title;
                query = query.Where(x => x.Title.Contains(title, StringComparison.OrdinalIgnoreCase));
            }

            return query;
        }

        /// <summary>
        /// One row per recipient, unread and stamped now. No recipients means every
        /// account that still works - that is what the screen's "All workers" sends.
        /// </summary>
        public async Task<NotificationSendResponse> SendAsync(NotificationSendRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);
            await _sendValidator.ValidateAndThrowAsync(request);

            var wanted = request.UserIds?.Distinct().ToList() ?? [];

            var recipients = wanted.Count == 0
                ? _dbContext.Users.Where(x => x.IsActive).Select(x => x.Id).ToList()
                : _dbContext.Users.Where(x => wanted.Contains(x.Id)).Select(x => x.Id).ToList();

            // An id that names nobody is worth reporting rather than quietly
            // dropping - the message would otherwise reach fewer people in silence.
            var missing = wanted.Except(recipients).ToList();
            if (missing.Count > 0)
            {
                throw new ClinetException($"No account with id {string.Join(", ", missing)}.");
            }

            if (recipients.Count == 0)
            {
                throw new ClinetException("There is nobody to send this to.");
            }

            var sentAt = DateTime.UtcNow;
            var notifications = recipients.Select(userId => new Notification
            {
                UserId = userId,
                Title = request.Title.Trim(),
                Message = request.Message.Trim(),
                IsRead = false,
                CreatedAt = sentAt,
            });

            await _dbContext.Notifications.AddRangeAsync(notifications);
            await _dbContext.SaveChangesAsync();

            return new NotificationSendResponse { SentCount = recipients.Count };
        }
    }
}
