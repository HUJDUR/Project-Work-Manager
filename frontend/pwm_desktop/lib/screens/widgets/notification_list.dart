import 'package:material_ui/material_ui.dart' hide Notification;

import '../../models/notification.dart';
import '../../providers/received_notifications_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/notification_groups.dart';
import '../../utils/notification_types.dart';

/// The body of a notification list — loading, empty, error, or the rows
/// themselves — shared between the bell's popup and the Notifications
/// screen's history card. They differ only in whether "Load more" is worth
/// offering: the bell shows a fixed unread page and points elsewhere for the
/// rest, the history card pages through everything.
class NotificationsList extends StatelessWidget {
  const NotificationsList({
    super.key,
    required this.provider,
    this.showLoadMore = true,
    this.emptyTitle = 'No notifications yet',
    this.emptyDetail = 'Messages from the office show up here.',
  });

  final ReceivedNotificationsProvider provider;
  final bool showLoadMore;
  final String emptyTitle;
  final String emptyDetail;

  @override
  Widget build(BuildContext context) {
    return switch (provider.status) {
      ReceivedNotificationsStatus.failed when provider.rows.isEmpty =>
        NotificationsMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Notifications could not be loaded',
          detail: provider.errorMessage ?? '',
          onRetry: provider.load,
        ),
      ReceivedNotificationsStatus.ready when provider.rows.isEmpty =>
        NotificationsMessage(
          icon: Icons.notifications_none_outlined,
          title: emptyTitle,
          detail: emptyDetail,
        ),
      ReceivedNotificationsStatus.loading ||
      ReceivedNotificationsStatus.idle =>
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      _ => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            for (final (day, rows)
                in groupNotificationsByDay(provider.rows, (row) => row.createdAt)) ...[
              NotificationDayHeader(label: day.label),
              for (final row in rows)
                NotificationTile(
                  notification: row,
                  onTap: () => provider.markRead(row),
                ),
            ],
            if (showLoadMore && provider.hasMore)
              NotificationsLoadMore(provider: provider),
            if (provider.errorMessage != null && provider.rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Text(
                  provider.errorMessage!,
                  style: TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ),
          ],
        ),
    };
  }
}

/// "Today", "Yesterday" or "Earlier" above the notifications that fall in it.
class NotificationDayHeader extends StatelessWidget {
  const NotificationDayHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// One message. Unread is said twice over — an accent rule down the leading
/// edge and a tinted ground — the same anatomy the mobile app's own
/// notification card uses.
class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.notification, required this.onTap});

  static const _rule = 3.0;

  final Notification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread ? AppColors.accentSoft : null,
        child: Stack(
          children: [
            if (isUnread)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _rule,
                child: ColoredBox(color: AppColors.accent),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14 + _rule, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notification.notificationTypeName.isNotEmpty) ...[
                    NotificationTypeLabel(name: notification.notificationTypeName),
                    const SizedBox(height: 3),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                isUnread ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          formatRelative(notification.createdAt),
                          style:
                              TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationsLoadMore extends StatelessWidget {
  const NotificationsLoadMore({super.key, required this.provider});

  final ReceivedNotificationsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: SizedBox(
        height: 36,
        child: OutlinedButton(
          onPressed: provider.isLoadingMore ? null : provider.loadMore,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: BorderSide(color: AppColors.accent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: provider.isLoadingMore
              ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              : const Text(
                  'Load more',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

class NotificationsMessage extends StatelessWidget {
  const NotificationsMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}
