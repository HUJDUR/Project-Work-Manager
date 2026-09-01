import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/recommendations_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/transport_screen.dart';
import '../screens/work_hours_screen.dart';
import '../screens/workers_screen.dart';
import '../utils/app_theme.dart';

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

  static const List<AppDestination> _destinations = [
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
  ];

  static Widget _dashboard(BuildContext context) => const DashboardScreen();
  static Widget _projects(BuildContext context) => const ProjectsScreen();
  static Widget _workHours(BuildContext context) => const WorkHoursScreen();
  static Widget _workers(BuildContext context) => const WorkersScreen();
  static Widget _transport(BuildContext context) => const TransportScreen();
  static Widget _reports(BuildContext context) => const ReportsScreen();
  static Widget _recommendations(BuildContext context) =>
      const RecommendationsScreen();
  static Widget _notifications(BuildContext context) => const NotificationsScreen();

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[_selectedIndex];

    return Scaffold(
      body: Column(
        children: [
          _TopBar(height: _topBarHeight),
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
  const _TopBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.precision_manufacturing_outlined,
                size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          const Column(
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
          IconButton(
            onPressed: () {},
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          const _AccountChip(),
        ],
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
      MaterialPageRoute(builder: (_) => const LoginScreen()),
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
              ? const Icon(Icons.person_outline, size: 19, color: AppColors.accent)
              : Text(
                  user.initials,
                  style: const TextStyle(
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
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
          ],
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          tooltip: 'Account',
          position: PopupMenuPosition.under,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          onSelected: (_) => _signOut(context),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'signOut',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 10),
                  Text('Sign out', style: TextStyle(fontSize: 13)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
