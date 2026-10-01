import 'package:material_ui/material_ui.dart';

import '../../utils/app_theme.dart';

/// One column of a table the API sorts and pages: [sortKey] is what the list
/// endpoint takes in `sortBy`.
class SortColumn {
  const SortColumn({required this.label, required this.flex, required this.sortKey});

  final String label;
  final int flex;
  final String sortKey;
}

/// A table's header where a click sorts by that column - the same look as
/// `ExcelHeaderRow`, for tables too large to download whole, which is what an
/// AutoFilter's checklist of every value would need.
class SortHeaderRow extends StatelessWidget {
  const SortHeaderRow({
    super.key,
    required this.columns,
    required this.sortKey,
    required this.ascending,
    required this.onSort,
    this.trailingWidth = 32,
  });

  final List<SortColumn> columns;
  final String sortKey;
  final bool ascending;
  final ValueChanged<String> onSort;

  /// Room for a row's own chevron, so the header lines up with the rows.
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          for (final (index, column) in columns.indexed) ...[
            if (index > 0) const SizedBox(width: 16),
            Expanded(
              flex: column.flex,
              child: _SortCell(
                label: column.label,
                sorted: column.sortKey == sortKey,
                ascending: ascending,
                onTap: () => onSort(column.sortKey),
              ),
            ),
          ],
          SizedBox(width: trailingWidth),
        ],
      ),
    );
  }
}

class _SortCell extends StatelessWidget {
  const _SortCell({
    required this.label,
    required this.sorted,
    required this.ascending,
    required this.onTap,
  });

  final String label;
  final bool sorted;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sorted ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
              ),
              if (sorted) ...[
                const SizedBox(width: 2),
                Icon(
                  ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: AppColors.accent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
