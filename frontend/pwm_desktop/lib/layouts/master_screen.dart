import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/account_settings_screen.dart';
import '../screens/administration_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/recommendations_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/transport_screen.dart';
import '../screens/widgets/notification_bell.dart';
import '../screens/work_hours_screen.dart';
import '../screens/workers_screen.dart';
import '../utils/app_roles.dart';
import '../utils/app_theme.dart';
import 'window_chrome.dart';

class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

class MasterScreen extends StatefulWidget {
  const MasterScreen({super.key});

  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> {
  static const _sidebarWidth = 248.0;
  static const _topBarHeight = 68.0;

  int _selectedIndex = 0;

  /// What this role may open. The sidebar is built from it, so an index always
  /// points at a screen the signed-in user is allowed to see.
  late final List<AppDestination> _destinations = _all
      .where((d) => AppRoles.canOpen(AuthProvider.role, d.label))
      .toList();

  static const List<AppDestination> _all = [
    AppDestination(
      label: 'Dashboard',
      icon: Icons.home_outlined,
      builder: _dashboard,
    ),
    AppDestination(
      label: 'Projects',
      icon: Icons.folder_outlined,
      builder: _projects,
    ),
    AppDestination(
      label: 'Work Hours',
      icon: Icons.schedule_outlined,
      builder: _workHours,
    ),
    AppDestination(
      label: 'Workers',
      icon: Icons.groups_outlined,
      builder: _workers,
    ),
    AppDestination(
      label: 'Transport',
      icon: Icons.local_shipping_outlined,
      builder: _transport,
    ),
    AppDestination(
      label: 'Reports',
      icon: Icons.bar_chart_outlined,
      builder: _reports,
    ),
    AppDestination(
      label: 'Recommendations',
      icon: Icons.star_outline,
      builder: _recommendations,
    ),
    AppDestination(
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      builder: _notifications,
    ),
    AppDestination(
      label: 'Administration',
      icon: Icons.admin_panel_settings_outlined,
      builder: _administration,
    ),
  ];

  static Widget _dashboard(BuildContext context) => DashboardScreen();
  static Widget _projects(BuildContext context) => ProjectsScreen();
  static Widget _workHours(BuildContext context) => WorkHoursScreen();
  static Widget _workers(BuildContext context) => WorkersScreen();
  static Widget _transport(BuildContext context) => TransportScreen();
  static Widget _reports(BuildContext context) => ReportsScreen();
  static Widget _recommendations(BuildContext context) =>
      RecommendationsScreen();
  static Widget _notifications(BuildContext context) => NotificationsScreen();
  static Widget _administration(BuildContext context) => AdministrationScreen();

  /// Switches to the Notifications screen — what the bell's "See all
  /// notifications" link opens. Every desktop role may open it, so this
  /// always finds it, but the lookup stays defensive rather than assuming a
  /// fixed index.
  void _openNotifications() {
    final index = _destinations.indexWhere((d) => d.label == 'Notifications');
    if (index >= 0) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[_selectedIndex];

    return Scaffold(
      body: Column(
        children: [
          _TopBar(height: _topBarHeight, onOpenNotifications: _openNotifications),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _sidebarWidth,
                  child: _Sidebar(
                    destinations: _destinations,
                    selectedIndex: _selectedIndex,
                    onSelected: (index) => setState(() => _selectedIndex = index),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  // A navigator per destination, so a list screen can push its
                  // details screen over the content while the top bar and the
                  // sidebar stay put. The key rebuilds it — and so reloads the
                  // screen — whenever the destination changes.
                  child: Navigator(
                    key: ValueKey(destination.label),
                    onGenerateRoute: (settings) => MaterialPageRoute(
                      settings: settings,
                      builder: destination.builder,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.height, required this.onOpenNotifications});

  final double height;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    // The bar doubles as the window's title bar: everything left of the caption
    // buttons drags the window, and the buttons run its full height at the right
    // edge so the whole thing reads as one row.
    return Container(
      height: height,
      color: AppColors.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DraggableBar(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 16),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.precision_manufacturing_outlined,
                          size: 20, color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Project Work Manager',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Metal fabrication shop',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _ThemeToggle(),
                    const SizedBox(width: 2),
                    NotificationBell(onViewAll: onOpenNotifications),
                    const SizedBox(width: 10),
                    _AccountChip(),
                  ],
                ),
              ),
            ),
          ),
          // A hairline keeps the window buttons from reading as app controls.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: SizedBox(width: 1, child: ColoredBox(color: AppColors.border)),
          ),
          // Outside the drag area, so a press on one is a click rather than the
          // start of a window move.
          WindowControls(height: height),
        ],
      ),
    );
  }
}

/// Flips the whole app between the two palettes. It sits next to the bell, as
/// the one piece of chrome that is a preference rather than a destination.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();

    return IconButton(
      onPressed: theme.toggle,
      tooltip: theme.isDark ? 'Switch to light theme' : 'Switch to dark theme',
      icon: Icon(
        theme.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip();

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context);

    await context.read<AuthProvider>().signOut();

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.accentSoft,
          child: user == null
              ? Icon(Icons.person_outline, size: 19, color: AppColors.accent)
              : Text(
                  user.initials,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              user?.fullName ?? 'Not signed in',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            if (auth.currentRole.isNotEmpty)
              Text(
                auth.currentRole,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
          ],
        ),
        SizedBox(width: 4),
        PopupMenuButton<String>(
          tooltip: 'Account',
          position: PopupMenuPosition.under,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          onSelected: (value) => value == 'settings'
              ? openAccountSettings(context)
              : _signOut(context),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.manage_accounts_outlined,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  const Text('Account settings', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'signOut',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  const Text('Sign out', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: ListView.builder(
        itemCount: destinations.length,
        itemBuilder: (context, index) => _NavItem(
          destination: destinations[index],
          selected: index == selectedIndex,
          onTap: () => onSelected(index),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(destination.icon, size: 20, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    destination.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: selected ? AppColors.accent : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
