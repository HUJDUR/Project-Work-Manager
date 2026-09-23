import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../providers/projects_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import 'excel_table_header.dart';
import 'table_pager.dart';

/// A state with no colour of its own.
const Color _neutral = Color(0xFF6B7280);

/// The breathing room between two columns of a row - matches the gap the
/// header already puts between its own cells.
const _columnGap = SizedBox(width: 16);

final _columns = <ExcelColumn<ProjectRow>>[
  ExcelColumn(
    label: 'Project',
    flex: 4,
    sortKey: (row) => row.name,
    filterValues: (row) => [row.name],
  ),
  ExcelColumn(
    label: 'Customer',
    flex: 3,
    sortKey: (row) => row.customerName,
    filterValues: (row) => [row.customerName],
  ),
  ExcelColumn(
    label: 'Category',
    flex: 3,
    sortKey: (row) => row.categoryName,
    filterValues: (row) => [row.categoryName],
  ),
  ExcelColumn(
    label: 'Status',
    // A hair wider than the other chip column: "In production" is the longest
    // status name and needs the room to stay on one line.
    flex: 3,
    sortKey: (row) => row.statusName,
    filterValues: (row) => [row.statusName],
  ),
  ExcelColumn(
    label: 'Priority',
    flex: 2,
    sortKey: (row) => row.priority.label,
    filterValues: (row) => [row.priority.label],
  ),
  ExcelColumn(
    label: 'Start Date',
    flex: 2,
    // ISO sorts chronologically as plain text; the formatted date shown in
    // the filter checklist below does not.
    sortKey: (row) => row.startDate?.toIso8601String() ?? '',
    filterValues: (row) =>
        [row.startDate == null ? ExcelColumn.blank : formatFullDate(row.startDate!)],
  ),
  ExcelColumn(
    label: 'End Date',
    flex: 2,
    sortKey: (row) => row.endDate?.toIso8601String() ?? '',
    filterValues: (row) =>
        [row.endDate == null ? ExcelColumn.blank : formatFullDate(row.endDate!)],
  ),
];

/// The project list with Excel's own AutoFilter, the same pattern the Workers
/// screen tried first: every header sorts on a click and carries a checklist
/// of that column's values to filter down to, over the whole matching set -
/// what the search box and status dropdown leave a match - rather than the
/// page of eight [ProjectsProvider] otherwise pages through. This widget
/// reads that whole set via [ProjectsProvider.loadAllRows] and paginates,
/// sorts and filters it here instead.
class ProjectsTable extends StatefulWidget {
  const ProjectsTable({super.key, required this.provider, required this.onRowTap});

  final ProjectsProvider provider;

  /// Opens the row in the details screen.
  final ValueChanged<ProjectRow> onRowTap;

  @override
  State<ProjectsTable> createState() => _ProjectsTableState();
}

enum _LoadStatus { loading, ready, failed }

class _ProjectsTableState extends State<ProjectsTable>
    with ExcelTableState<ProjectRow, ProjectsTable> {
  _LoadStatus _status = _LoadStatus.loading;
  List<ProjectRow> _allRows = const [];

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant ProjectsTable oldWidget) {
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

  /// The search box and status dropdown each notify the provider on change,
  /// and so does a save on the details screen - any of those can change which
  /// rows this table should hold, so all of them re-fetch it.
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
        ? const <ProjectRow>[]
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
          ExcelHeaderRow<ProjectRow>(
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
                    'Could not load the full project list.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              _ => pageRows.isEmpty
                  ? _NoRows()
                  : ListView.separated(
                      itemCount: pageRows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => _ProjectRowTile(
                        row: pageRows[index],
                        onTap: () => widget.onRowTap(pageRows[index]),
                      ),
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

class _ProjectRowTile extends StatelessWidget {
  const _ProjectRowTile({required this.row, required this.onTap});

  final ProjectRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(flex: _columns[0].flex, child: _Project(row: row)),
            _columnGap,
            Expanded(flex: _columns[1].flex, child: _Cell(row.customerName)),
            _columnGap,
            Expanded(flex: _columns[2].flex, child: _Cell(row.categoryName)),
            _columnGap,
            Expanded(
              flex: _columns[3].flex,
              child: ProjectStatusChip(status: row.statusName),
            ),
            _columnGap,
            Expanded(
              flex: _columns[4].flex,
              child: ProjectPriorityChip(priority: row.priority),
            ),
            _columnGap,
            Expanded(
              flex: _columns[5].flex,
              child: _Cell(row.startDate == null ? '—' : formatFullDate(row.startDate!)),
            ),
            _columnGap,
            Expanded(
              flex: _columns[6].flex,
              child: _Cell(row.endDate == null ? '—' : formatFullDate(row.endDate!)),
            ),
            SizedBox(
              width: 32,
              child: Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Project extends StatelessWidget {
  const _Project({required this.row});

  final ProjectRow row;

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
          child: Icon(Icons.folder_outlined, size: 17, color: AppColors.accent),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _Cell(
            row.name,
            caption: '${row.code} · ${formatTonnes(row.weight)}',
          ),
        ),
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

/// Colours the seeded `ProjectStatusTypes` by how far along a project is;
/// an unknown name falls back to neutral rather than guessing.
class ProjectStatusChip extends StatelessWidget {
  const ProjectStatusChip({super.key, required this.status});

  /// One colour per state; the background is derived from it so the chip works
  /// on a white card and a dark one alike.
  static const _palette = <String, Color>{
    'in production': Color(0xFF2563EB),
    'on hold': Color(0xFF9A6212),
    'delivered': Color(0xFF107A4D),
    'rejected': Color(0xFFB91C1C),
  };

  final String status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) =
        AppColors.chip(_palette[status.toLowerCase()] ?? _neutral);

    return Align(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

/// The four hardcoded levels, warm as they get more urgent.
class ProjectPriorityChip extends StatelessWidget {
  const ProjectPriorityChip({super.key, required this.priority});

  static const _palette = <ProjectPriority, Color>{
    ProjectPriority.low: _neutral,
    ProjectPriority.medium: Color(0xFF2563EB),
    ProjectPriority.high: Color(0xFF9A6212),
    ProjectPriority.veryHigh: Color(0xFFB91C1C),
  };

  final ProjectPriority priority;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = AppColors.chip(_palette[priority]!);

    return Align(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          priority.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _NoRows extends StatelessWidget {
  const _NoRows();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No projects match the current filters.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}
