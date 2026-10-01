import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../providers/work_hours_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import 'sort_header.dart';
import 'table_pager.dart';

/// The breathing room between two columns of a row - matches the gap the
/// header already puts between its own cells.
const _columnGap = SizedBox(width: 16);

const _columns = <SortColumn>[
  SortColumn(label: 'Worker', flex: 3, sortKey: 'Worker'),
  SortColumn(label: 'Project', flex: 3, sortKey: 'Project'),
  SortColumn(label: 'Date', flex: 2, sortKey: 'Date'),
  SortColumn(label: 'Regular Hours', flex: 2, sortKey: 'RegularHours'),
  SortColumn(label: 'Overtime Hours', flex: 2, sortKey: 'OvertimeHours'),
  SortColumn(label: 'Total Hours', flex: 2, sortKey: 'TotalHours'),
  SortColumn(label: 'Status', flex: 2, sortKey: 'Status'),
];

/// One page of work hours as [WorkHoursProvider] holds it. The API filters,
/// sorts and pages - the table is thousands of rows - so a header click and
/// the pager both go back to it.
class WorkHoursTable extends StatelessWidget {
  const WorkHoursTable({super.key, required this.provider, required this.onRowTap});

  final WorkHoursProvider provider;

  /// Opens the row in the details screen.
  final ValueChanged<WorkHoursEntry> onRowTap;

  @override
  Widget build(BuildContext context) {
    final rows = provider.entries;

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
          SortHeaderRow(
            columns: _columns,
            sortKey: provider.sortKey,
            ascending: provider.sortAscending,
            onSort: provider.setSort,
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? _NoRows()
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _EntryRow(
                      entry: rows[index],
                      onTap: () => onRowTap(rows[index]),
                    ),
                  ),
          ),
          const Divider(height: 1),
          TablePager(
            page: provider.page,
            pageCount: provider.pageCount,
            onPageChanged: provider.setPage,
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
            _columnGap,
            Expanded(
              flex: _columns[1].flex,
              child: _Cell(entry.projectName, caption: entry.operationName),
            ),
            _columnGap,
            Expanded(flex: _columns[2].flex, child: _Cell(formatFullDate(entry.date))),
            _columnGap,
            Expanded(
              flex: _columns[3].flex,
              child: _Cell(formatHours(entry.regularHours)),
            ),
            _columnGap,
            Expanded(
              flex: _columns[4].flex,
              child: _Cell(
                entry.isOvertime ? formatHours(entry.overtimeHours) : '—',
                color: entry.isOvertime ? AppColors.accent : AppColors.textMuted,
              ),
            ),
            _columnGap,
            Expanded(
              flex: _columns[5].flex,
              child: _Cell(formatHours(entry.totalHours), bold: true),
            ),
            _columnGap,
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
