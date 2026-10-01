using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using pwm.Services.Messaging;

namespace pwm.Services.Database
{
    /// <summary>
    /// Pushes "your notifications changed" to every account a save just wrote a
    /// notification for - whoever wrote it: a manual send, a status change, a
    /// password-reset request, the worker's missed clock-out watchdog. Hooked into
    /// the save itself so no code path can add a notification and forget to tell
    /// anyone, and only after the save commits, so an app never reloads to find
    /// nothing new. Scoped, like the context it is attached to.
    /// </summary>
    public sealed class NotificationPushInterceptor : SaveChangesInterceptor
    {
        private readonly INotificationPushPublisher _publisher;
        private int[] _pending = [];

        public NotificationPushInterceptor(INotificationPushPublisher publisher)
        {
            _publisher = publisher;
        }

        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            Collect(eventData.Context);
            return base.SavingChangesAsync(eventData, result, cancellationToken);
        }

        public override async ValueTask<int> SavedChangesAsync(
            SaveChangesCompletedEventData eventData,
            int result,
            CancellationToken cancellationToken = default)
        {
            var userIds = TakePending();
            if (userIds.Length > 0)
            {
                await _publisher.PublishAsync(userIds, cancellationToken);
            }

            return await base.SavedChangesAsync(eventData, result, cancellationToken);
        }

        public override Task SaveChangesFailedAsync(
            DbContextErrorEventData eventData, CancellationToken cancellationToken = default)
        {
            TakePending();
            return base.SaveChangesFailedAsync(eventData, cancellationToken);
        }

        private void Collect(DbContext? context)
        {
            if (context is null)
            {
                return;
            }

            _pending = context.ChangeTracker.Entries<Notification>()
                .Where(x => x.State == EntityState.Added)
                .Select(x => x.Entity.UserId)
                .Distinct()
                .ToArray();
        }

        private int[] TakePending()
        {
            var userIds = _pending;
            _pending = [];
            return userIds;
        }
    }
}
