import 'package:flutter/material.dart';

import '../../models/project_priority.dart';
import '../../utils/app_theme.dart';

/// A status or priority pill, tinted from the one colour that names the state.
///
/// The desktop builds its chips the same way — store the accent, let the theme
/// derive the (background, foreground) pair — so light and dark both read. An
/// unknown name falls back to neutral rather than guessing a colour.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.accent});

  /// The colours a project status is written in, keyed by the seeded name.
  static const _statusColours = <String, Color>{
    'in production': Color(0xFF2563EB),
    'delivered': Color(0xFF059669),
    'on hold': Color(0xFFD97706),
    'rejected': Color(0xFFDC2626),
  };

  static const _priorityColours = <ProjectPriority, Color>{
    ProjectPriority.low: Color(0xFF64748B),
    ProjectPriority.medium: Color(0xFF2563EB),
    ProjectPriority.high: Color(0xFFD97706),
    ProjectPriority.veryHigh: Color(0xFFDC2626),
  };

  factory StatusPill.status(String name) => StatusPill(
        label: name,
        accent: _statusColours[name.toLowerCase()] ?? neutral,
      );

  factory StatusPill.priority(ProjectPriority priority) => StatusPill(
        label: priority.label,
        accent: _priorityColours[priority] ?? neutral,
      );

  /// A state with no colour of its own.
  static Color get neutral =>
      AppColors.isDark ? const Color(0xFF9AA3AE) : const Color(0xFF4B5563);

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = AppColors.chip(accent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
