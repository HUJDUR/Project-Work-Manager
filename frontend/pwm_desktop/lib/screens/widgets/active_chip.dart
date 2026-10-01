import 'package:material_ui/material_ui.dart';

import '../../utils/app_theme.dart';

/// "Active" / "Inactive" for a record that is deactivated rather than deleted -
/// a worker's account, a company.
class ActiveChip extends StatelessWidget {
  const ActiveChip({super.key, required this.isActive});

  final bool isActive;

  static String labelFor(bool isActive) => isActive ? 'Active' : 'Inactive';

  @override
  Widget build(BuildContext context) {
    final (background, foreground) =
        AppColors.chip(isActive ? const Color(0xFF107A4D) : const Color(0xFF6B7280));

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          labelFor(isActive),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: foreground),
        ),
      ),
    );
  }
}
