import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../providers/activities_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import 'excel_table_header.dart';
import 'table_pager.dart';

/// The breathing room between two columns of a row - matches the gap the
/// header already puts between its own cells.
const _columnGap = SizedBox(width: 16);

/// Room for the header's own trailing space, so a row without a chevron of
/// its own still lines its last column up under the header.
const _trailingWidth = 32.0;

final _columns = <ExcelColumn<ActivityRow>>[
  ExcelColumn(
    label: 'User',
    flex: 3,
    sortKey: (row) => row.userName,
    filterValues: (row) => [row.userName],
  ),
  ExcelColumn(
    label: 'Activity',
    flex: 4,
    sortKey: (row) => row.activityTypeName,
    filterValues: (row) => [row.activityTypeName],
  ),
  ExcelColumn(
    label: 'Date',
    flex: 3,
    sortKey: (row) => row.date.toIso8601String(),
    filterValues: (row) => [formatFullDate(row.date)],
  ),
];

/// The activity log with Excel's own AutoFilter, the same pattern the
/// Workers, Projects and Transport screens already use: every header sorts on
/// a click and carries a checklist of that column's values to filter down to -
/// filter enough that the screen needs no dropdowns of its own. This widget
/// reads the whole log via [ActivitiesProvider.loadAllRows] and paginates,
/// sorts and filters it here, defaulting to newest first.
class ActivitiesTable extends StatefulWidget {
  const ActivitiesTable({super.key, required this.provider});

  final ActivitiesProvider provider;

  @override
  State<ActivitiesTable> createState() => _ActivitiesTableState();
}

enum _LoadStatus { loading, ready, failed }

class _ActivitiesTableState extends State<ActivitiesTable>
    with ExcelTableState<ActivityRow, ActivitiesTable> {
  _LoadStatus _status = _LoadStatus.loading;
  List<ActivityRow> _allRows = const [];

  @override
  void initState() {
    super.initState();
    // Newest first by default, the same order the API sends it in - not just
    // once a click on the header asks for it.
    sortColumn = _columns[2];
    sortAscending = false;
    widget.provider.addListener(_onProviderChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant ActivitiesTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      oldWidget.provider.removeListener(_onProviderChanged);
      widget.provider.addListener(_onProviderChanged);
      _load();
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  /// A re-fetch of the provider — there is nothing on this screen to filter
  /// it, but the listener stays wired the same way every other Excel table's
  /// does, in case a future write ever needs to refresh it.
  void _onProviderChanged() => _load();

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);

    try {
      final rows = await widget.provider.loadAllRows();
      if (!mounted) return;
      setState(() {
        _allRows = rows;
        _status = _LoadStatus.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = visibleRows(_allRows);
    final pageCount = (rows.length / ExcelTableState.pageSize).ceil().clamp(1, 999);
    final currentPage = page.clamp(1, pageCount);
    final start = (currentPage - 1) * ExcelTableState.pageSize;
    final pageRows = start >= rows.length
        ? const <ActivityRow>[]
        : rows.sublist(start, (start + ExcelTableState.pageSize).clamp(0, rows.length));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcelHeaderRow<ActivityRow>(
            columns: _columns,
            allRows: _allRows,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            filters: columnFilters,
            onResult: (column, result) => onHeaderResult(_allRows, column, result),
          ),
          const Divider(height: 1),
          Expanded(
            child: switch (_status) {
              _LoadStatus.loading when _allRows.isEmpty =>
                const Center(child: CircularProgressIndicator()),
              _LoadStatus.failed => Center(
                  child: Text(
                    'Could not load the activity log.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              _ => pageRows.isEmpty
                  ? _NoRows()
                  : ListView.separated(
                      itemCount: pageRows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => _ActivityRowTile(row: pageRows[index]),
                    ),
            },
          ),
          const Divider(height: 1),
          TablePager(
            page: currentPage,
            pageCount: pageCount,
            onPageChanged: (value) => setState(() => page = value),
          ),
        ],
      ),
    );
  }
}

/// Not wrapped in an `InkWell`: there is no details screen to open, an
/// activity is just a fact of record.
class _ActivityRowTile extends StatelessWidget {
  const _ActivityRowTile({required this.row});

  final ActivityRow row;

  @override
  Widget build(BuildContext context) {
    final local = row.date;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: _columns[0].flex, child: _User(row: row)),
          _columnGap,
          Expanded(flex: _columns[1].flex, child: _Cell(row.activityTypeName)),
          _columnGap,
          Expanded(
            flex: _columns[2].flex,
            child: _Cell(formatFullDate(local), caption: formatTime(local)),
          ),
          const SizedBox(width: _trailingWidth),
        ],
      ),
    );
  }
}

class _User extends StatelessWidget {
  const _User({required this.row});

  final ActivityRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            row.userInitials,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _Cell(row.userName)),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.value, {this.caption});

  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        if (caption != null)
          Text(
            caption!,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

class _NoRows extends StatelessWidget {
  const _NoRows();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No activity matches the current filters.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}
