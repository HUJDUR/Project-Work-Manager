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
          const _HeaderRow(),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const _NoRows()
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _ProjectRowTile(
                      row: rows[index],
                      onTap: () => onRowTap(rows[index]),
                    ),
                  ),
          ),
          const Divider(height: 1),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          for (final column in _columns)
            Expanded(
              flex: column.flex,
              child: Text(
                column.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(width: 32),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            const SizedBox(
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
          child: const Icon(Icons.folder_outlined, size: 17, color: AppColors.accent),
        ),
        const SizedBox(width: 10),
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        if (caption != null)
          Text(
            caption!,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

/// Colours the six seeded `ProjectStatusTypes` by how far along a project is;
/// an unknown name falls back to neutral rather than guessing.
class ProjectStatusChip extends StatelessWidget {
  const ProjectStatusChip({super.key, required this.status});

  static const _palette = <String, (Color, Color)>{
    'new': (Color(0xFFF1F3F6), Color(0xFF4B5563)),
    'in preparation': (Color(0xFFFDF3E3), Color(0xFF9A6212)),
    'in production': (AppColors.accentSoft, AppColors.accent),
    'ready for delivery': (Color(0xFFEDE9FE), Color(0xFF6D3EDB)),
    'delivered': (Color(0xFFEAF7F0), Color(0xFF107A4D)),
    'cancelled': (AppColors.dangerSoft, AppColors.danger),
  };

  final String status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) =
        _palette[status.toLowerCase()] ?? _palette['new']!;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  static const _palette = <ProjectPriority, (Color, Color)>{
    ProjectPriority.low: (Color(0xFFF1F3F6), Color(0xFF4B5563)),
    ProjectPriority.medium: (AppColors.accentSoft, AppColors.accent),
    ProjectPriority.high: (Color(0xFFFDF3E3), Color(0xFF9A6212)),
    ProjectPriority.veryHigh: (AppColors.dangerSoft, AppColors.danger),
  };

  final ProjectPriority priority;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _palette[priority]!;

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
    return const Center(
      child: Text(
        'No projects match the current filters.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}
