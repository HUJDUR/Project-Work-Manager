import 'package:flutter/material.dart' hide Notification;
import 'package:provider/provider.dart';

import '../models/notification.dart';
import '../providers/notifications_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

/// The Notifications tab: what the office has sent this worker.
///
/// There is no mockup in `docs/mockups/mobile` for this one — it was designed to
/// sit with the others and follows their anatomy: the same heading and subtitle,
/// the same card, the same "Load more" as the Projects tab.
///
/// The shape of the screen is the one thing a notification list has to get
/// right, which is **read against unread**. That is said three ways rather than
/// one, because it is the only thing on the screen worth saying: a count and a
/// filter at the top, a tint and an accent rule on the card, and the weight of
/// its title. Everything else — sender, type, priority — is either not in the
/// table or not the shop floor's business.
///
/// The office sends these from the desktop's Send Notification screen. Nothing
/// here writes one: the only write this screen makes is marking its own read.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, this.providerFactory});

  /// Lets a test swap in a provider backed by fake data.
  final NotificationsProvider Function()? providerFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          (providerFactory?.call() ?? NotificationsProvider())..load(),
      child: Consumer<NotificationsProvider>(
        builder: (context, provider, _) => _Body(provider: provider),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.provider});

  final NotificationsProvider provider;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// Which cards are showing their message in full, by notification id. It is
  /// view state and lives here rather than on the provider — reloading the list
  /// should not re-collapse what the reader opened, and the provider has no
  /// business knowing.
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          const SizedBox(height: 4),
          Text(
            'Notifications',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Messages from the office',
            style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _UnreadBar(provider: provider),
          const SizedBox(height: 14),
          _FilterBar(provider: provider),
          ..._results(),
        ],
      ),
    );
  }

  List<Widget> _results() {
    final provider = widget.provider;

    return switch (provider.status) {
      NotificationsStatus.failed when provider.rows.isEmpty => [
        _Message(
          icon: Icons.cloud_off_outlined,
          title: 'Notifications could not be loaded',
          detail: provider.errorMessage ?? '',
          onRetry: provider.load,
        ),
      ],
      NotificationsStatus.ready when provider.rows.isEmpty => [
        _Message(
          icon: provider.filter == NotificationsFilter.unread
              ? Icons.done_all
              : Icons.notifications_none_outlined,
          title: provider.filter == NotificationsFilter.unread
              ? 'Nothing unread'
              : 'No notifications yet',
          detail: provider.filter == NotificationsFilter.unread
              ? 'Everything the office has sent you has been read.'
              : 'Messages from the office show up here.',
        ),
      ],
      NotificationsStatus.loading => [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      _ => [
        const SizedBox(height: 16),
        Text(
          _countLabel(
            provider.totalCount,
            provider.rows.length,
            provider.filter,
          ),
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        for (final row in provider.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NotificationCard(
              notification: row,
              isExpanded: _expanded.contains(row.id),
              onTap: () => _open(row),
            ),
          ),
        if (provider.hasMore) _LoadMore(provider: provider),
        // A failure while appending or marking leaves what is already on
        // screen and says what went wrong under it, rather than throwing the
        // list away.
        if (provider.errorMessage != null && provider.rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.danger),
          ),
        ],
      ],
    };
  }

  /// Opening a notification is what reads it, so the tap does both: it shows the
  /// message in full and tells the API. A second tap only folds it back up —
  /// the provider ignores a row that is already read.
  void _open(Notification notification) {
    setState(() {
      if (!_expanded.remove(notification.id)) _expanded.add(notification.id);
    });

    widget.provider.markRead(notification);
  }

  static String _countLabel(int? total, int shown, NotificationsFilter filter) {
    final noun = filter == NotificationsFilter.unread
        ? 'unread'
        : 'notifications';
    final one = filter == NotificationsFilter.unread
        ? '1 unread'
        : '1 notification';

    if (total == null) return '$shown $noun';
    if (shown >= total) return total == 1 ? one : '$total $noun';
    return '$shown of $total $noun';
  }
}

/// How many are unread, and the one button that changes it.
///
/// It scrolls with the list rather than being pinned above it, the way every
/// other tab in this app puts its heading in the scroll flow — and it sits high
/// enough that it is on screen when the tab opens, which is when it is wanted.
class _UnreadBar extends StatelessWidget {
  const _UnreadBar({required this.provider});

  final NotificationsProvider provider;

  @override
  Widget build(BuildContext context) {
    final unread = provider.unreadCount;
    final hasUnread = unread > 0;
    final (background, foreground) = AppColors.chip(AppColors.accent);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: hasUnread ? background : AppColors.fieldFill,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            hasUnread ? '$unread unread' : 'All read',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: hasUnread ? foreground : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Disabled rather than hidden: a button that comes and goes is a button
        // the thumb has to look for, and "All read" beside it already says why
        // it does nothing.
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _MarkAllButton(
              isBusy: provider.isMarking,
              onTap: hasUnread && !provider.isMarking
                  ? provider.markAllRead
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Mark all as read", built by hand rather than as a `TextButton.icon`.
///
/// Material's own button carries a 64px minimum width and padding of its own on
/// top of whatever is asked for, which put this label 34px over the edge of a
/// 390pt phone. The label shrinks in a `FittedBox` besides — the same thing the
/// bottom bar does with "Notifications", and for the same reason.
class _MarkAllButton extends StatelessWidget {
  const _MarkAllButton({required this.isBusy, required this.onTap});

  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colour = onTap == null ? AppColors.textMuted : AppColors.accent;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colour,
                  ),
                )
              else
                Icon(Icons.done_all, size: 18, color: colour),
              const SizedBox(width: 7),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mark all as read',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: colour,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// All against unread, as two pills. Both go to the API as `isRead`, so this is
/// a filter and not a client-side sift.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.provider});

  final NotificationsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final filter in NotificationsFilter.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _FilterPill(
              label: filter.label,
              isSelected: provider.filter == filter,
              onTap: () => provider.applyFilter(filter),
            ),
          ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.accent : AppColors.fieldFill,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.fieldBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// One message. Unread is said twice over — an accent rule down the leading edge
/// and a tinted ground — because on a phone in a workshop one of the two is
/// usually being looked at in bad light or at arm's length.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isExpanded,
    required this.onTap,
  });

  static const _rule = 3.0;

  final Notification notification;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final radius = BorderRadius.circular(AppSpacing.cardRadius);

    return Material(
      color: isUnread ? AppColors.accentSoft : AppColors.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isUnread ? AppColors.accent : AppColors.border,
            ),
          ),
          // A Stack, so the rule can run the card's full height without the card
          // having a height to hand: the text sizes the Stack and the rule is
          // stretched to it. A Row of `CrossAxisAlignment.stretch` cannot do
          // that here — inside a list there is no bounded height to stretch to,
          // and it passes an infinite one down — and a thicker left `BorderSide`
          // cannot either, because a `BoxDecoration` border has to be uniform to
          // carry a `borderRadius`.
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
                padding: const EdgeInsets.fromLTRB(14 + _rule, 13, 14, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.25,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          // Sits on the title's first line rather than its top.
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            formatRelative(apiTimeToLocal(notification.createdAt)),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      maxLines: isExpanded ? null : 2,
                      overflow: isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadMore extends StatelessWidget {
  const _LoadMore({required this.provider});

  final NotificationsProvider provider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: provider.isLoadingMore ? null : provider.loadMore,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: BorderSide(color: AppColors.accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: provider.isLoadingMore
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            : const Text(
                'Load more',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
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
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}
