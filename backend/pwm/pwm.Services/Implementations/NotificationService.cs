using FluentValidation;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using pwm.Model.Access;
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
        private readonly IActivityLogService _activityLogService;
        private readonly ICurrentUser _currentUser;

        public NotificationService(
            PWMDbContext dbContext,
            IMapper mapper,
            IValidator<NotificationSendRequest> sendValidator,
            IActivityLogService activityLogService,
            ICurrentUser currentUser)
            : base(mapper, dbContext)
        {
            _sendValidator = sendValidator;
            _activityLogService = activityLogService;
            _currentUser = currentUser;
        }

        /// <summary>Somebody else's notification is not found, whatever the role.</summary>
        public override async Task<NotificationResponse> GetByIdAsync(int id)
        {
            var notification = await base.GetByIdAsync(id);

            if (notification.UserId != _currentUser.Id)
            {
                throw new NotFoundException($"Notification with id {id} not found.");
            }

            return notification;
        }

        protected override IQueryable<Notification> ApplyFilters(IQueryable<Notification> query, NotificationSearchObject? search)
        {
            // A notification is personal: every role reads only its own, and which
            // account that is comes from the token - search.UserId is not looked at.
            var userId = _currentUser.Id ?? throw new ForbiddenException("The token carries no user.");
            query = query.Where(x => x.UserId == userId);

            if (search == null)
            {
                return query;
            }

            if (search.IsRead.HasValue)
            {
                query = query.Where(x => x.IsRead == search.IsRead.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.Title))
            {
                var title = search.Title;
                query = query.Where(x => EF.Functions.Like(x.Title, $"%{title}%"));
            }

            return query;
        }

        /// <summary>
        /// One row per recipient, unread and stamped now. No recipients means every
        /// account that still works - that is what the screen's "All workers" sends.
        /// </summary>
        public async Task<NotificationSendResponse> SendAsync(int senderId, NotificationSendRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);
            await _sendValidator.ValidateAndThrowAsync(request);

            var wanted = request.UserIds?.Distinct().ToList() ?? [];

            var recipients = wanted.Count == 0
                ? await _dbContext.Users.Where(x => x.IsActive).Select(x => x.Id).ToListAsync()
                : await _dbContext.Users.Where(x => wanted.Contains(x.Id)).Select(x => x.Id).ToListAsync();

            // An id that names nobody is worth reporting rather than quietly
            // dropping - the message would otherwise reach fewer people in silence.
            var missing = wanted.Except(recipients).ToList();
            if (missing.Count > 0)
            {
                throw new ClientException($"No account with id {string.Join(", ", missing)}.");
            }

            if (recipients.Count == 0)
            {
                throw new ClientException("There is nobody to send this to.");
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
            // Tracked on the same context, not saved yet - see RecordAsync's doc.
            await _activityLogService.RecordAsync(senderId, ActivityLogTypeNames.MessageSent);
            // One commit for both: the notifications and the audit row are one
            // operation, not two independently-committed writes.
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
                ? await mine.Where(x => !x.IsRead).ToListAsync()
                : await mine.Where(x => wanted.Contains(x.Id)).ToListAsync();

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
                // Tracked on the same context, not saved yet - see RecordAsync's doc.
                await _activityLogService.RecordAsync(userId, ActivityLogTypeNames.MarkedMessagesAsRead);
                // One commit for both the read flags and the audit row.
                await _dbContext.SaveChangesAsync();
            }

            return new NotificationMarkReadResponse { MarkedCount = unread.Count };
        }

        public async Task StageForRolesAsync(string title, string message, int? exceptUserId, params string[] roles)
        {
            var recipientIds = await _dbContext.Users
                .Where(x => x.IsActive && roles.Contains(x.UserType.Type) && x.Id != exceptUserId)
                .Select(x => x.Id)
                .ToListAsync();

            var sentAt = DateTime.UtcNow;

            _dbContext.Notifications.AddRange(recipientIds.Select(userId => new Notification
            {
                UserId = userId,
                Title = title,
                Message = message,
                IsRead = false,
                CreatedAt = sentAt,
            }));
        }

        /// <summary>
        /// One notification straight to every active Admin, naming whoever asked -
        /// see the interface doc for why this is not just <see cref="SendAsync"/>
        /// with an Admin-only recipient list.
        /// </summary>
        public async Task NotifyAdminsOfPasswordResetRequestAsync(
            int requesterId, string requesterName, string requesterEmail)
        {
            var adminIds = await _dbContext.Users
                .Where(x => x.IsActive && x.UserType.Type == Roles.Admin)
                .Select(x => x.Id)
                .ToListAsync();

            if (adminIds.Count == 0)
            {
                return;
            }

            var sentAt = DateTime.UtcNow;
            var message = $"{requesterName} ({requesterEmail}) asked for their password to be reset.";

            var notifications = adminIds.Select(adminId => new Notification
            {
                UserId = adminId,
                Title = "Password reset requested",
                Message = message,
                IsRead = false,
                CreatedAt = sentAt,
            });

            await _dbContext.Notifications.AddRangeAsync(notifications);
            // Tracked on the same context, not saved yet - see RecordAsync's doc.
            await _activityLogService.RecordAsync(requesterId, ActivityLogTypeNames.PasswordResetRequested);
            // One commit for both: the notifications and the audit row are one operation.
            await _dbContext.SaveChangesAsync();
        }
    }
}
