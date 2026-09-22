import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import 'excel_table_header.dart';
import 'table_pager.dart';

final _columns = <ExcelColumn<WorkHoursEntry>>[
  ExcelColumn(
    label: 'Worker',
    flex: 3,
    sortKey: (entry) => entry.workerName,
    filterValues: (entry) => [entry.workerName],
  ),
  ExcelColumn(
    label: 'Project',
    flex: 3,
    sortKey: (entry) => entry.projectName,
    filterValues: (entry) => [entry.projectName],
  ),
  ExcelColumn(
    label: 'Date',
    flex: 2,
    // ISO sorts chronologically as plain text; the formatted date shown in
    // the filter checklist below does not.
    sortKey: (entry) => entry.date.toIso8601String(),
    filterValues: (entry) => [formatFullDate(entry.date)],
  ),
  ExcelColumn(
    label: 'Regular Hours',
    flex: 2,
    sortKey: (entry) => entry.regularHours.toString(),
    filterValues: (entry) => [formatHours(entry.regularHours)],
  ),
  ExcelColumn(
    label: 'Overtime Hours',
    flex: 2,
    sortKey: (entry) => entry.overtimeHours.toString(),
    filterValues: (entry) => [entry.isOvertime ? formatHours(entry.overtimeHours) : '—'],
  ),
  ExcelColumn(
    label: 'Total Hours',
    flex: 2,
    sortKey: (entry) => entry.totalHours.toString(),
    filterValues: (entry) => [formatHours(entry.totalHours)],
  ),
  ExcelColumn(
    label: 'Status',
    flex: 2,
    sortKey: (entry) => entry.status == WorkHoursStatus.completed ? 'Completed' : 'In progress',
    filterValues: (entry) => [entry.status == WorkHoursStatus.completed ? 'Completed' : 'In progress'],
  ),
];

/// The work hours list with Excel's own AutoFilter, the same pattern the
/// Workers screen tried first: every header sorts on a click and carries a
/// checklist of that column's values to filter down to. [WorkHoursProvider]
/// already reads every block whole and filters it client-side, so unlike the
/// paged tables this one only adds sort, per-column filter and pagination
/// on top of the (already complete) [entries] it is handed.
class WorkHoursTable extends StatefulWidget {
  const WorkHoursTable({super.key, required this.entries, required this.onRowTap});

  final List<WorkHoursEntry> entries;

  /// Opens the row in the details screen.
  final ValueChanged<WorkHoursEntry> onRowTap;

  @override
  State<WorkHoursTable> createState() => _WorkHoursTableState();
}

class _WorkHoursTableState extends State<WorkHoursTable>
    with ExcelTableState<WorkHoursEntry, WorkHoursTable> {
  @override
  void didUpdateWidget(covariant WorkHoursTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The filter bar (search, project, date range, overtime/in-progress) can
    // narrow entries out from under an applied column filter or push the
    // current page past the end; back to page one keeps that consistent.
    if (oldWidget.entries != widget.entries) page = 1;
  }

  @override
  Widget build(BuildContext context) {
    final rows = visibleRows(widget.entries);
    final pageCount = (rows.length / ExcelTableState.pageSize).ceil().clamp(1, 999);
    final currentPage = page.clamp(1, pageCount);
    final start = (currentPage - 1) * ExcelTableState.pageSize;
    final pageRows = start >= rows.length
        ? const <WorkHoursEntry>[]
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
          ExcelHeaderRow<WorkHoursEntry>(
            columns: _columns,
            allRows: widget.entries,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            filters: columnFilters,
            onResult: (column, result) => onHeaderResult(widget.entries, column, result),
          ),
          const Divider(height: 1),
          Expanded(
            child: pageRows.isEmpty
                ? _NoRows()
                : ListView.separated(
                    itemCount: pageRows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _EntryRow(
                      entry: pageRows[index],
                      onTap: () => widget.onRowTap(pageRows[index]),
                    ),
                  ),
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

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onTap});

  final WorkHoursEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(flex: _columns[0].flex, child: _Worker(entry: entry)),
            Expanded(
              flex: _columns[1].flex,
              child: _Cell(entry.projectName, caption: entry.operationName),
            ),
            Expanded(flex: _columns[2].flex, child: _Cell(formatFullDate(entry.date))),
            Expanded(
              flex: _columns[3].flex,
              child: _Cell(formatHours(entry.regularHours)),
            ),
            Expanded(
              flex: _columns[4].flex,
              child: _Cell(
                entry.isOvertime ? formatHours(entry.overtimeHours) : '—',
                color: entry.isOvertime ? AppColors.accent : AppColors.textMuted,
              ),
            ),
            Expanded(
              flex: _columns[5].flex,
              child: _Cell(formatHours(entry.totalHours), bold: true),
            ),
            Expanded(flex: _columns[6].flex, child: _StatusChip(status: entry.status)),
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

class _Worker extends StatelessWidget {
  const _Worker({required this.entry});

  final WorkHoursEntry entry;

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
            entry.workerInitials,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _Cell(entry.workerName)),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.value, {this.caption, this.color, this.bold = false});

  final String value;
  final String? caption;
  final Color? color;
  final bool bold;

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
            color: color ?? AppColors.textPrimary,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final WorkHoursStatus status;

  @override
  Widget build(BuildContext context) {
    final completed = status == WorkHoursStatus.completed;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: completed ? const Color(0xFFEAF7F0) : AppColors.accentSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          completed ? 'Completed' : 'In progress',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: completed ? const Color(0xFF107A4D) : AppColors.accent,
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
        'No work hours match the current filters.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}
