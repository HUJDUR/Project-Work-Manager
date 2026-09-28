import 'package:flutter/material.dart' hide Notification;

import '../../providers/received_notifications_provider.dart';
import '../../utils/app_theme.dart';
import 'notification_list.dart';

/// The top bar's bell: a badge for how many are unread, and a popup listing
/// the newest of them with a way to clear all of it at once.
///
/// Read here means read for good — nothing un-reads a notification — but a
/// notification the bell already showed keeps showing, struck through, for
/// the rest of the session: only signing out and back in drops it, because
/// that is when `MasterScreen` — which owns [provider], not this widget —
/// rebuilds it from nothing. Anything older, or already read before this
/// session, lives in the Notifications screen's history card instead — that
/// is what [onViewAll] opens.
///
/// The provider is owned by the caller rather than created here because
/// `MasterScreen` also has to reach it: it calls
/// `ReceivedNotificationsProvider.refreshUnread` on every screen change and
/// on its own poll timer, so a notification sent mid-session shows up
/// without waiting for the next sign-in - or even for the office to switch
/// screens. Owning it locally would leave `MasterScreen` with no way in.
class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    required this.provider,
    required this.onViewAll,
  });

  final ReceivedNotificationsProvider provider;

  /// Switches the app to the Notifications screen, where the history card
  /// shows everything the bell does not.
  final VoidCallback onViewAll;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _link = LayerLink();

  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onChanged);
  }

  @override
  void dispose() {
    _entry?.remove();
    widget.provider.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (_entry != null) {
      _close();
      return;
    }

    _entry = OverlayEntry(
      builder: (context) => _NotificationsOverlay(
        link: _link,
        provider: widget.provider,
        onDismiss: _close,
        onViewAll: () {
          _close();
          widget.onViewAll();
        },
      ),
    );
    Overlay.of(context).insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final unread = widget.provider.unreadCount;

    return CompositedTransformTarget(
      link: _link,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: _toggle,
            tooltip: 'Notifications',
            icon: Icon(
              _entry != null ? Icons.notifications : Icons.notifications_none,
              color: _entry != null ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
          if (unread > 0)
            Positioned(
              right: 6,
              top: 6,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.surface, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The popup itself: a barrier that closes it on an outside click, and the
/// panel following the bell.
class _NotificationsOverlay extends StatelessWidget {
  const _NotificationsOverlay({
    required this.link,
    required this.provider,
    required this.onDismiss,
    required this.onViewAll,
  });

  final LayerLink link;
  final ReceivedNotificationsProvider provider;
  final VoidCallback onDismiss;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 10),
          child: GestureDetector(
            // Absorbs taps on the panel itself so they do not fall through to
            // the barrier behind it and close the popup.
            onTap: () {},
            // The overlay entry's own builder only runs once on insert, so the
            // panel has to listen for itself to pick up a load, a mark-read or
            // a mark-all-read.
            child: ListenableBuilder(
              listenable: provider,
              builder: (context, _) => _NotificationsPanel(
                provider: provider,
                onViewAll: onViewAll,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel({required this.provider, required this.onViewAll});

  final ReceivedNotificationsProvider provider;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PanelHeader(provider: provider),
              const Divider(height: 1),
              Flexible(
                child: NotificationsList(
                  provider: provider,
                  showLoadMore: false,
                  emptyTitle: 'No new notifications',
                  emptyDetail: 'You are all caught up.',
                ),
              ),
              const Divider(height: 1),
              _ViewAllRow(onTap: onViewAll),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.provider});

  final ReceivedNotificationsProvider provider;

  @override
  Widget build(BuildContext context) {
    final unread = provider.unreadCount;
    final canMarkAll = unread > 0 && !provider.isMarking;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  unread > 0 ? '$unread unread' : 'All read',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: canMarkAll ? provider.markAllRead : null,
            icon: provider.isMarking
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textMuted,
                    ),
                  )
                : const Icon(Icons.done_all, size: 16),
            label: const Text('Mark all as read', style: TextStyle(fontSize: 12.5)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewAllRow extends StatelessWidget {
  const _ViewAllRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'See all notifications',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}
