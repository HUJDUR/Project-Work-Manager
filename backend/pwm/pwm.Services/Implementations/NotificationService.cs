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

        /// <summary>
        /// Marks the caller's own notifications read - no ids means every unread
        /// one of theirs, which is the mobile screen's "Mark all as read".
        ///
        /// A notification is personal, so there is no role that reads somebody
        /// else's: <paramref name="userId"/> comes from the token and narrows the
        /// rows before the ids are looked at, which is why an id belonging to
        /// another account is refused rather than found.
        /// </summary>
        public async Task<NotificationMarkReadResponse> MarkReadAsync(int userId, NotificationMarkReadRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);

            var wanted = request.NotificationIds?.Distinct().ToList() ?? [];
            var mine = _dbContext.Notifications.Where(x => x.UserId == userId);

            var rows = wanted.Count == 0
                ? mine.Where(x => !x.IsRead).ToList()
                : mine.Where(x => wanted.Contains(x.Id)).ToList();

            var missing = wanted.Except(rows.Select(x => x.Id)).ToList();
            if (missing.Count > 0)
            {
                throw new ForbiddenException(
                    $"No notification of yours with id {string.Join(", ", missing)}.");
            }

            // Only the unread ones are touched, so the count says what actually
            // changed rather than how many rows were named.
            var unread = rows.Where(x => !x.IsRead).ToList();

            foreach (var row in unread)
            {
                row.IsRead = true;
            }

            if (unread.Count > 0)
            {
                await _dbContext.SaveChangesAsync();
            }

            return new NotificationMarkReadResponse { MarkedCount = unread.Count };
        }
    }
}
