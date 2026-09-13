import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/widgets/placeholder_body.dart';
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
  const MasterScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> {
  static const _topBarHeight = 60.0;

  late int _selectedIndex = widget.initialIndex;

  /// Only Dashboard has a body so far; the rest render [PlaceholderBody].
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
      builder: (go) => PlaceholderBody(title: 'Clock In'),
    ),
    AppDestination(
      label: 'My Hours',
      icon: Icons.schedule_outlined,
      activeIcon: Icons.schedule,
      builder: (go) => PlaceholderBody(title: 'My Hours'),
    ),
    AppDestination(
      label: 'Projects',
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder,
      builder: (go) => PlaceholderBody(title: 'Projects'),
    ),
    AppDestination(
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      builder: (go) => PlaceholderBody(title: 'Notifications'),
    ),
    AppDestination(
      label: 'Options',
      icon: Icons.more_horiz_outlined,
      activeIcon: Icons.more_horiz,
      builder: (go) => PlaceholderBody(title: 'Options'),
    ),
  ];

  /// Switches tab by label rather than index, so reordering the bar cannot
  /// silently send "View all" somewhere else.
  void _go(String label) {
    final index = _destinations.indexWhere((d) => d.label == label);
    if (index >= 0) setState(() => _selectedIndex = index);
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
            _TopBar(
              height: _topBarHeight,
              onNotifications: () => _go('Notifications'),
            ),
            const Divider(height: 1),
            Expanded(child: destination.builder(_go)),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        destinations: _destinations,
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.height, required this.onNotifications});

  final double height;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final user = AuthProvider.user;

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
          IconButton(
            onPressed: onNotifications,
            tooltip: 'Notifications',
            // Material's default 48px tap target crowds the title on a phone.
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.notifications_outlined,
              size: 23,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: user == null
                ? Icon(Icons.person, size: 20, color: AppColors.textSecondary)
                : Text(
                    user.initials,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
          ),
          const SizedBox(width: 4),
        ],
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
    required this.onSelected,
  });

  static const _height = 60.0;

  final List<AppDestination> destinations;
  final int selectedIndex;
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
    required this.onTap,
  });

  final AppDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = isSelected ? AppColors.accent : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? destination.activeIcon : destination.icon,
            size: 22,
            color: colour,
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
