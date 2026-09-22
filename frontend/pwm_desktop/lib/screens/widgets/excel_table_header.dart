import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// One column's identity for an Excel-style table header: what it sorts and
/// filters by. Generic over the row type so one implementation of the header,
/// menu and filter panel serves every table that wants this - first tried on
/// the Workers screen, then carried over to Projects, Work Hours and
/// Transport once it held up there.
class ExcelColumn<T> {
  const ExcelColumn({
    required this.label,
    required this.flex,
    required this.sortKey,
    required this.filterValues,
  });

  final String label;
  final int flex;

  /// What a click on "Sort A to Z" / "Sort Z to A" compares.
  final String Function(T row) sortKey;

  /// What a row offers the column's filter checklist. Most columns offer one
  /// value; a column like Operations can offer several, and a row matches the
  /// filter if it holds any of the values checked - closer to what a filter on
  /// a multi-valued column should do than Excel's own literal-text match.
  final List<String> Function(T row) filterValues;

  /// What an empty cell offers its own column's checklist and filters under.
  static const blank = '(Blank)';
}

enum ExcelMenuAction { sortAscending, sortDescending, applyFilter, clearFilter }

class ExcelMenuResult {
  const ExcelMenuResult(this.action, [this.selected]);

  final ExcelMenuAction action;

  /// Set only for [ExcelMenuAction.applyFilter].
  final Set<String>? selected;
}

/// A table's whole header: one [ExcelColumn] per cell, each carrying Excel's
/// own AutoFilter - sort A-Z / Z-A, then a search box over a checklist of
/// every value the column holds across [allRows], not just the page on
/// screen. A tap reports back through [onResult]; the caller owns the sort
/// and filter state and decides what the result changes.
class ExcelHeaderRow<T> extends StatelessWidget {
  const ExcelHeaderRow({
    super.key,
    required this.columns,
    required this.allRows,
    required this.sortColumn,
    required this.sortAscending,
    required this.filters,
    required this.onResult,
    this.trailingWidth = 32,
  });

  final List<ExcelColumn<T>> columns;
  final List<T> allRows;
  final ExcelColumn<T>? sortColumn;
  final bool sortAscending;

  /// The filter checked for each column that has one - absent means every
  /// value of that column passes.
  final Map<ExcelColumn<T>, Set<String>> filters;

  final void Function(ExcelColumn<T> column, ExcelMenuResult result) onResult;

  /// Room for a row's own chevron or delete button, so the header's cells
  /// line up with the rows below it.
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
              child: Builder(
                builder: (headerContext) => _HeaderCell(
                  label: column.label,
                  sorted: sortColumn == column,
                  ascending: sortAscending,
                  filtered: filters.containsKey(column),
                  onTap: () => _open(context, headerContext, column),
                ),
              ),
            ),
          ],
          SizedBox(width: trailingWidth),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, BuildContext headerContext, ExcelColumn<T> column) async {
    final renderBox = headerContext.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlay),
        renderBox.localToGlobal(renderBox.size.bottomLeft(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final allValues = {for (final row in allRows) ...column.filterValues(row)}.toList()..sort();

    final result = await showMenu<ExcelMenuResult>(
      context: context,
      position: position,
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 260, maxHeight: 420),
      items: [
        PopupMenuItem<ExcelMenuResult>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _ColumnFilterPanel(
            allValues: allValues,
            selected: filters[column],
            sorted: sortColumn == column,
            sortAscending: sortAscending,
          ),
        ),
      ],
    );

    if (result != null) onResult(column, result);
  }
}

/// One pressable, Excel-style column header: a label, an arrow that becomes a
/// sort direction once the column is the one the table is sorted by, and a
/// small funnel once a filter narrows it.
class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.sorted,
    required this.ascending,
    required this.filtered,
    required this.onTap,
  });

  final String label;
  final bool sorted;
  final bool ascending;
  final bool filtered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = sorted || filtered;

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
                    color: active ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                sorted
                    ? (ascending ? Icons.arrow_upward : Icons.arrow_downward)
                    : Icons.arrow_drop_down,
                size: sorted ? 14 : 18,
                color: active ? AppColors.accent : AppColors.textMuted,
              ),
              if (filtered)
                Padding(
                  padding: const EdgeInsets.only(left: 1),
                  child: Icon(Icons.filter_alt, size: 11, color: AppColors.accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The popup itself: sort A-Z / Z-A at the top, then a search box narrowing a
/// checklist of every value the column holds - Excel's AutoFilter panel.
class _ColumnFilterPanel extends StatefulWidget {
  const _ColumnFilterPanel({
    required this.allValues,
    required this.selected,
    required this.sorted,
    required this.sortAscending,
  });

  final List<String> allValues;

  /// Null means no filter is applied - every value counts as checked.
  final Set<String>? selected;
  final bool sorted;
  final bool sortAscending;

  @override
  State<_ColumnFilterPanel> createState() => _ColumnFilterPanelState();
}

class _ColumnFilterPanelState extends State<_ColumnFilterPanel> {
  late final Set<String> _checked = widget.selected ?? widget.allValues.toSet();
  String _search = '';

  List<String> get _shown => _search.isEmpty
      ? widget.allValues
      : widget.allValues
          .where((value) => value.toLowerCase().contains(_search.toLowerCase()))
          .toList();

  bool get _allShownChecked => _shown.isNotEmpty && _shown.every(_checked.contains);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MenuAction(
          icon: Icons.arrow_upward,
          label: 'Sort A to Z',
          selected: widget.sorted && widget.sortAscending,
          onTap: () =>
              Navigator.pop(context, const ExcelMenuResult(ExcelMenuAction.sortAscending)),
        ),
        _MenuAction(
          icon: Icons.arrow_downward,
          label: 'Sort Z to A',
          selected: widget.sorted && !widget.sortAscending,
          onTap: () =>
              Navigator.pop(context, const ExcelMenuResult(ExcelMenuAction.sortDescending)),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search, size: 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        CheckboxListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('(Select All)'),
          value: _allShownChecked,
          onChanged: (checked) => setState(() {
            if (checked ?? false) {
              _checked.addAll(_shown);
            } else {
              _checked.removeAll(_shown);
            }
          }),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final value in _shown)
                CheckboxListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(value, overflow: TextOverflow.ellipsis),
                  value: _checked.contains(value),
                  onChanged: (checked) => setState(() {
                    if (checked ?? false) {
                      _checked.add(value);
                    } else {
                      _checked.remove(value);
                    }
                  }),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              TextButton(
                onPressed: widget.selected == null
                    ? null
                    : () => Navigator.pop(
                          context,
                          const ExcelMenuResult(ExcelMenuAction.clearFilter),
                        ),
                child: const Text('Clear Filter'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _checked.isEmpty
                    ? null
                    : () => Navigator.pop(
                          context,
                          ExcelMenuResult(ExcelMenuAction.applyFilter, Set.of(_checked)),
                        ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 15, color: selected ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? AppColors.accent : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row's value for one filtered column, sorted, filtered and paginated the
/// same way regardless of which table asks - the state every
/// `_ExcelTableState` keeps and applies to its own full row list.
mixin ExcelTableState<T, W extends StatefulWidget> on State<W> {
  static const pageSize = 8;

  int page = 1;
  ExcelColumn<T>? sortColumn;
  bool sortAscending = true;
  final Map<ExcelColumn<T>, Set<String>> columnFilters = {};

  bool _matchesFilters(T row) {
    for (final entry in columnFilters.entries) {
      final values = entry.key.filterValues(row);
      if (!values.any(entry.value.contains)) return false;
    }
    return true;
  }

  List<T> visibleRows(List<T> allRows) {
    final filtered = allRows.where(_matchesFilters).toList();

    final column = sortColumn;
    if (column != null) {
      filtered.sort((a, b) {
        final result = _compare(column.sortKey(a), column.sortKey(b));
        return sortAscending ? result : -result;
      });
    }

    return filtered;
  }

  /// Numeric where a column's sort keys are all numbers - e.g. a weight -
  /// case-insensitive text otherwise, so "10" does not sort before "9".
  static int _compare(String a, String b) {
    final numA = num.tryParse(a);
    final numB = num.tryParse(b);
    if (numA != null && numB != null) return numA.compareTo(numB);
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  void onHeaderResult(List<T> allRows, ExcelColumn<T> column, ExcelMenuResult result) {
    setState(() {
      switch (result.action) {
        case ExcelMenuAction.sortAscending:
          sortColumn = column;
          sortAscending = true;
        case ExcelMenuAction.sortDescending:
          sortColumn = column;
          sortAscending = false;
        case ExcelMenuAction.applyFilter:
          final allValues = {for (final row in allRows) ...column.filterValues(row)};
          if (result.selected!.length == allValues.length) {
            columnFilters.remove(column);
          } else {
            columnFilters[column] = result.selected!;
          }
        case ExcelMenuAction.clearFilter:
          columnFilters.remove(column);
      }
      page = 1;
    });
  }
}
