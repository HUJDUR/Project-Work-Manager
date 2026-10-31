import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The seeded type names (`NotificationTypeRules` on the API) each get their
/// own icon; a type the office adds later falls back to the bell.
IconData notificationTypeIcon(String name) => switch (name) {
      'Reminder' => Icons.alarm_outlined,
      'Safety' => Icons.health_and_safety_outlined,
      'Schedule' => Icons.event_outlined,
      'Missed clock-out' => Icons.timer_off_outlined,
      'Absence' => Icons.person_off_outlined,
      'Work hours change' => Icons.edit_calendar_outlined,
      'Project status' => Icons.folder_outlined,
      'Transport status' => Icons.local_shipping_outlined,
      'Password reset' => Icons.lock_reset_outlined,
      _ => Icons.notifications_outlined,
    };

/// The type above a notification's title: its icon and name.
class NotificationTypeLabel extends StatelessWidget {
  const NotificationTypeLabel({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(notificationTypeIcon(name), size: 14, color: AppColors.accent),
        const SizedBox(width: 5),
        Text(
          name,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent),
        ),
      ],
    );
  }
}
