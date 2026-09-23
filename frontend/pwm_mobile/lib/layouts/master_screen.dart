import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notifications_provider.dart';
import '../screens/clock_in_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/my_hours_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/options_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/widgets/account_menu.dart';
import '../utils/app_theme.dart';

/// One entry in the bottom navigation.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Built with a way back to the shell, so a screen can send the user to
  /// another tab — the dashboard's "View all" is the one that does.
  final Widget Function(void Function(String label) go) builder;
}

/// The app frame: the top bar the mockups wear, a body that swaps with the
/// selected tab, and the six-entry bottom navigation.
///
/// Like the desktop's `MasterScreen` this is a shell, not a wrapper — it owns
/// the selected index and swaps its body, rather than each screen wrapping
/// itself and navigating by push.
class MasterScreen extends StatefulWidget {
  const MasterScreen({
    super.key,
    this.initialIndex = 0,
    this.notificationsProviderFactory,
  });

  final int initialIndex;

  /// Lets a test swap in the badge's provider backed by fake data.
  final NotificationsProvider Function()? notificationsProviderFactory;

  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> {
  static const _topBarHeight = 60.0;

  late int _selectedIndex = widget.initialIndex;

  /// Tracked here rather than only inside the Notifications tab, so the
  /// bottom bar can badge it even while some other tab is showing — the
  /// mobile equivalent of the desktop's bell badge. It is its own instance,
  /// separate from the one the tab itself builds when it is open, so it is
  /// refreshed by hand on every tab switch rather than kept in step
  /// automatically: see `_selectTab`.
  late final _notifications =
      widget.notificationsProviderFactory?.call() ?? NotificationsProvider();

  @override
  void initState() {
    super.initState();
    _notifications.addListener(_onNotificationsChanged);
    _notifications.load();
  }

  @override
  void dispose() {
    _notifications.removeListener(_onNotificationsChanged);
    _notifications.dispose();
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  /// Switches tabs by index, the way the bottom bar itself picks one, and
  /// re-asks for the unread count on every change — not only when leaving
  /// the Notifications tab — so a notification sent while some other tab is
  /// open still reaches the badge, the same as the desktop bell now checks
  /// on every screen change too.
  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
    _notifications.load();
  }

  /// Every entry has a screen behind it.
  static final List<AppDestination> _destinations = [
    AppDestination(
      label: 'Dashboard',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      builder: (go) => DashboardScreen(onViewAllHours: () => go('My Hours')),
    ),
    AppDestination(
      label: 'Clock In',
      icon: Icons.play_circle_outline,
      activeIcon: Icons.play_circle,
      builder: (go) => ClockInScreen(),
    ),
    AppDestination(
      label: 'My Hours',
      icon: Icons.schedule_outlined,
      activeIcon: Icons.schedule,
      builder: (go) => MyHoursScreen(),
    ),
    AppDestination(
      label: 'Projects',
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder,
      builder: (go) => ProjectsScreen(),
    ),
    AppDestination(
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      builder: (go) => NotificationsScreen(),
    ),
    AppDestination(
      label: 'Options',
      icon: Icons.more_horiz_outlined,
      activeIcon: Icons.more_horiz,
      builder: (go) => OptionsScreen(),
    ),
  ];

  /// Switches tab by label rather than index, so reordering the bar cannot
  /// silently send "View all" somewhere else.
  void _go(String label) {
    final index = _destinations.indexWhere((d) => d.label == label);
    if (index >= 0) _selectTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[_selectedIndex];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(height: _topBarHeight),
            const Divider(height: 1),
            Expanded(child: destination.builder(_go)),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        destinations: _destinations,
        selectedIndex: _selectedIndex,
        notificationsUnreadCount: _notifications.unreadCount,
        onSelected: _selectTab,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: AppColors.surface,
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.precision_manufacturing_outlined,
              size: 19,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            // The product's name, so it shrinks to fit a narrow phone rather
            // than ellipsising to "PWM - Project Work M…".
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'PWM - Project Work Manager',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          _ThemeToggle(),
          const SizedBox(width: 6),
          AccountMenuButton(),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Flips the whole app between the two palettes — the one piece of chrome
/// that is a preference rather than a destination, which is why it reads a
/// shade quieter than the account menu beside it.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();

    return IconButton(
      onPressed: theme.toggle,
      tooltip: theme.isDark ? 'Switch to light theme' : 'Switch to dark theme',
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      icon: Icon(
        theme.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        size: 21,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Six tabs is more than Material's `BottomNavigationBar` lays out comfortably,
/// so the bar is built by hand: an even row of icon-over-label columns.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.destinations,
    required this.selectedIndex,
    required this.notificationsUnreadCount,
    required this.onSelected,
  });

  static const _height = 60.0;

  final List<AppDestination> destinations;
  final int selectedIndex;

  /// Badges the Notifications tab — the bottom bar's answer to the desktop's
  /// bell badge, for the one tab that is not always on screen to speak for
  /// itself.
  final int notificationsUnreadCount;

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _height,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _BottomBarItem(
                    destination: destinations[i],
                    isSelected: i == selectedIndex,
                    badgeCount: destinations[i].label == 'Notifications'
                        ? notificationsUnreadCount
                        : 0,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.destination,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  final AppDestination destination;
  final bool isSelected;

  /// A red count on the icon's corner — zero draws nothing.
  final int badgeCount;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = isSelected ? AppColors.accent : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isSelected ? destination.activeIcon : destination.icon,
                size: 22,
                color: colour,
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -6,
                  top: -3,
                  child: _UnreadBadge(count: badgeCount),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            // Six labels share the width of a phone and "Notifications" is the
            // longest of them, so it shrinks to fit rather than ellipsising —
            // a bottom bar reading "Notificat…" names nothing.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                destination.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: colour,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The desktop bell's badge, on a bottom-bar icon instead: a small red count
/// for whatever a tab that is not the current one has waiting.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
