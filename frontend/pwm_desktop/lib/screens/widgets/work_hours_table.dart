import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';

const _columns = <_Column>[
  _Column('Worker', 3),
  _Column('Project', 3),
  _Column('Date', 2),
  _Column('Regular Hours', 2),
  _Column('Overtime Hours', 2),
  _Column('Total Hours', 2),
  _Column('Status', 2),
];

class _Column {
  const _Column(this.label, this.flex);

  final String label;
  final int flex;
}

class WorkHoursTable extends StatelessWidget {
  const WorkHoursTable({super.key, required this.entries});

  final List<WorkHoursEntry> entries;

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
            child: entries.isEmpty
                ? const _NoRows()
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _EntryRow(entry: entries[index]),
                  ),
          ),
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
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final WorkHoursEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
        ],
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
            style: const TextStyle(
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
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
    return const Center(
      child: Text(
        'No work hours match the current filters.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}
