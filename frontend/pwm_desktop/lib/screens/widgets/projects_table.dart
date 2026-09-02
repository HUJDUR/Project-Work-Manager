import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import 'table_pager.dart';

const _columns = <_Column>[
  _Column('Project', 4),
  _Column('Customer', 3),
  _Column('Category', 2),
  _Column('Status', 2),
  _Column('Priority', 2),
  _Column('Start Date', 2),
  _Column('End Date', 2),
];

/// A state with no colour of its own.
const Color _neutral = Color(0xFF6B7280);

class _Column {
  const _Column(this.label, this.flex);

  final String label;
  final int flex;
}

class ProjectsTable extends StatelessWidget {
  const ProjectsTable({
    super.key,
    required this.rows,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
    required this.onRowTap,
  });

  final List<ProjectRow> rows;
  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  /// Opens the row in the details screen.
  final ValueChanged<ProjectRow> onRowTap;

  @override
  Widget build(BuildContext context) {
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
          _HeaderRow(),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? _NoRows()
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _ProjectRowTile(
                      row: rows[index],
                      onTap: () => onRowTap(rows[index]),
                    ),
                  ),
          ),
          Divider(height: 1),
          TablePager(page: page, pageCount: pageCount, onPageChanged: onPageChanged),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          for (final column in _columns)
            Expanded(
              flex: column.flex,
              child: Text(
                column.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          SizedBox(width: 32),
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
            Expanded(flex: _columns[1].flex, child: _Cell(row.customerName)),
            Expanded(flex: _columns[2].flex, child: _Cell(row.categoryName)),
            Expanded(
              flex: _columns[3].flex,
              child: ProjectStatusChip(status: row.statusName),
            ),
            Expanded(
              flex: _columns[4].flex,
              child: ProjectPriorityChip(priority: row.priority),
            ),
            Expanded(
              flex: _columns[5].flex,
              child: _Cell(row.startDate == null ? '—' : formatFullDate(row.startDate!)),
            ),
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

/// Colours the six seeded `ProjectStatusTypes` by how far along a project is;
/// an unknown name falls back to neutral rather than guessing.
class ProjectStatusChip extends StatelessWidget {
  const ProjectStatusChip({super.key, required this.status});

  /// One colour per state; the background is derived from it so the chip works
  /// on a white card and a dark one alike.
  static const _palette = <String, Color>{
    'new': _neutral,
    'in preparation': Color(0xFF9A6212),
    'in production': Color(0xFF2563EB),
    'ready for delivery': Color(0xFF6D3EDB),
    'delivered': Color(0xFF107A4D),
    'cancelled': Color(0xFFB91C1C),
  };

  final String status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) =
        AppColors.chip(_palette[status.toLowerCase()] ?? _neutral);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          status,
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
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          priority.label,
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
