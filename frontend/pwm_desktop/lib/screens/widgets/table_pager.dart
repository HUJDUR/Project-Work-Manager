import 'package:material_ui/material_ui.dart';

import '../../utils/app_theme.dart';

/// `< 1 2 3 … 10 >` under a table, as in the projects mockup. Long runs collapse
/// around the current page.
class TablePager extends StatelessWidget {
  const TablePager({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  List<int?> get _slots {
    if (pageCount <= 7) {
      return [for (var i = 1; i <= pageCount; i++) i];
    }

    final around = <int>{1, pageCount, page - 1, page, page + 1}
        .where((value) => value >= 1 && value <= pageCount)
        .toList()
      ..sort();

    final slots = <int?>[];
    for (var i = 0; i < around.length; i++) {
      if (i > 0 && around[i] - around[i - 1] > 1) slots.add(null);
      slots.add(around[i]);
    }

    return slots;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ArrowButton(
            icon: Icons.chevron_left,
            tooltip: 'Previous page',
            onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
          ),
          for (final slot in _slots)
            slot == null
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('…', style: TextStyle(color: AppColors.textMuted)),
                  )
                : _PageButton(
                    page: slot,
                    selected: slot == page,
                    onPressed: () => onPageChanged(slot),
                  ),
          _ArrowButton(
            icon: Icons.chevron_right,
            tooltip: 'Next page',
            onPressed: page < pageCount ? () => onPageChanged(page + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.page,
    required this.selected,
    required this.onPressed,
  });

  final int page;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(
        width: 34,
        height: 34,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: selected ? AppColors.accent : AppColors.textPrimary,
            backgroundColor: selected ? AppColors.accentSoft : null,
            side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(
        width: 34,
        height: 34,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AppColors.textSecondary,
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Tooltip(message: tooltip, child: Icon(icon, size: 18)),
        ),
      ),
    );
  }
}
