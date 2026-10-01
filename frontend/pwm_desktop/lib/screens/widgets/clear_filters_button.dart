import 'package:material_ui/material_ui.dart';

import '../../utils/app_theme.dart';

/// The funnel icon every filter bar ends on. It used to open a menu whose
/// only real action was "Clear filters" - one extra click to reach the one
/// thing it did - so it is a direct button instead: filled in once a filter
/// is active, disabled (nothing to clear) otherwise.
class ClearFiltersButton extends StatelessWidget {
  const ClearFiltersButton({super.key, required this.hasFilters, required this.onPressed});

  final bool hasFilters;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Clear all filters',
      onPressed: hasFilters ? onPressed : null,
      icon: Icon(
        Icons.filter_alt_off_outlined,
        color: hasFilters ? AppColors.accent : AppColors.textMuted,
      ),
      style: IconButton.styleFrom(
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
