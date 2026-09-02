import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../utils/app_theme.dart';
import 'table_pager.dart';

const _columns = <_Column>[
  _Column('Worker', 4),
  _Column('Job Title', 3),
  _Column('Role', 2),
  _Column('Phone', 2),
  _Column('Operations', 4),
  _Column('Status', 2),
];

/// A state with no colour of its own.
const Color _neutral = Color(0xFF6B7280);

class _Column {
  const _Column(this.label, this.flex);

  final String label;
  final int flex;
}

class WorkersTable extends StatelessWidget {
  const WorkersTable({
    super.key,
    required this.rows,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
    required this.onRowTap,
  });

  final List<WorkerRow> rows;
  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  /// Opens the row in the details screen.
  final ValueChanged<WorkerRow> onRowTap;

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
                    itemBuilder: (context, index) => _WorkerRowTile(
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
                style: TextStyle(
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

class _WorkerRowTile extends StatelessWidget {
  const _WorkerRowTile({required this.row, required this.onTap});

  final WorkerRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(flex: _columns[0].flex, child: _Worker(row: row)),
            Expanded(flex: _columns[1].flex, child: _Cell(row.jobTitle)),
            Expanded(flex: _columns[2].flex, child: _RoleChip(role: row.roleName)),
            Expanded(flex: _columns[3].flex, child: _Cell(row.phoneNumber ?? '—')),
            Expanded(
              flex: _columns[4].flex,
              child: _Operations(operations: row.operations),
            ),
            Expanded(
              flex: _columns[5].flex,
              child: _StatusChip(isActive: row.isActive),
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

class _Worker extends StatelessWidget {
  const _Worker({required this.row});

  final WorkerRow row;

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
            row.initials,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _Cell(row.fullName, caption: row.email)),
      ],
    );
  }
}

/// The first two qualifications, with a count for the rest — the full list is
/// too wide for a column and office staff have none at all.
class _Operations extends StatelessWidget {
  const _Operations({required this.operations});

  static const _shown = 2;

  final List<String> operations;

  @override
  Widget build(BuildContext context) {
    if (operations.isEmpty) {
      return _Cell('—');
    }

    final extra = operations.length - _shown;

    return _Cell(
      operations.take(_shown).join(', '),
      caption: extra > 0 ? '+$extra more' : null,
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

/// The three seeded `UserTypes`; an unknown role falls back to neutral.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  static const _palette = <String, Color>{
    'administrator': Color(0xFF6D3EDB),
    'manager': Color(0xFF9A6212),
    'worker': Color(0xFF2563EB),
  };

  final String role;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) =
        AppColors.chip(_palette[role.toLowerCase()] ?? _neutral);

    return _Chip(label: role, background: background, foreground: foreground);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) =
        AppColors.chip(isActive ? const Color(0xFF107A4D) : _neutral);

    return _Chip(
      label: isActive ? 'Active' : 'Inactive',
      background: background,
      foreground: foreground,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
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
        'No workers match the current filters.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}
