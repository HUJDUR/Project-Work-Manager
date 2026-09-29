import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../providers/workers_provider.dart';
import '../../utils/app_theme.dart';
import 'excel_table_header.dart';
import 'table_pager.dart';
import 'user_avatar.dart';

/// Gap between every column, in both the header and the rows, so a long value
/// in one never visually crowds the next.
const _columnGap = SizedBox(width: 16);

/// A state with no colour of its own.
const Color _neutral = Color(0xFF6B7280);

final _columns = <ExcelColumn<WorkerRow>>[
  ExcelColumn(
    label: 'Worker',
    flex: 4,
    sortKey: (row) => row.fullName,
    filterValues: (row) => [row.fullName],
  ),
  ExcelColumn(
    label: 'Role',
    flex: 3,
    sortKey: (row) => row.roleName,
    filterValues: (row) => [row.roleName],
  ),
  ExcelColumn(
    label: 'Phone',
    flex: 2,
    sortKey: (row) => row.phoneNumber ?? '',
    filterValues: (row) => [row.phoneNumber ?? ExcelColumn.blank],
  ),
  ExcelColumn(
    label: 'Operations',
    flex: 3,
    sortKey: (row) => row.operations.join(', '),
    filterValues: (row) => row.operations.isEmpty ? [ExcelColumn.blank] : row.operations,
  ),
  ExcelColumn(
    label: 'Status',
    flex: 2,
    sortKey: (row) => row.isActive ? 'Active' : 'Inactive',
    filterValues: (row) => [row.isActive ? 'Active' : 'Inactive'],
  ),
];

/// The workers list with Excel's own AutoFilter, tried here first: every
/// header sorts on a click and carries a checklist of that column's values to
/// filter the table down to. That needs the whole matching set in hand at
/// once - what the search box, role dropdown and "Currently employed" toggle
/// leave a match - rather than the page of eight [WorkersProvider] otherwise
/// pages through, so this widget reads it directly via [WorkersProvider.
/// loadAllRows] and paginates, sorts and filters it here instead.
class WorkersTable extends StatefulWidget {
  const WorkersTable({super.key, required this.provider, required this.onRowTap});

  final WorkersProvider provider;

  /// Opens the row in the details screen.
  final ValueChanged<WorkerRow> onRowTap;

  @override
  State<WorkersTable> createState() => _WorkersTableState();
}

enum _LoadStatus { loading, ready, failed }

class _WorkersTableState extends State<WorkersTable> with ExcelTableState<WorkerRow, WorkersTable> {
  _LoadStatus _status = _LoadStatus.loading;
  List<WorkerRow> _allRows = const [];

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant WorkersTable oldWidget) {
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

  /// The search box, role dropdown and active toggle each notify the provider
  /// on change, and so does a save on the details screen - any of those can
  /// change which rows this table should hold, so all of them re-fetch it.
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
        ? const <WorkerRow>[]
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
          ExcelHeaderRow<WorkerRow>(
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
                    'Could not load the full worker list.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              _ => pageRows.isEmpty
                  ? _NoRows()
                  : ListView.separated(
                      itemCount: pageRows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => _WorkerRowTile(
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
            _columnGap,
            Expanded(flex: _columns[1].flex, child: _RoleChip(role: row.roleName)),
            _columnGap,
            Expanded(flex: _columns[2].flex, child: _Cell(row.phoneNumber ?? '—')),
            _columnGap,
            Expanded(
              flex: _columns[3].flex,
              child: _Operations(operations: row.operations),
            ),
            _columnGap,
            Expanded(
              flex: _columns[4].flex,
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
        // Initials only: list responses carry no pictures, and a table of
        // thumbnails would mean one picture request per row.
        UserAvatar(
          picture: null,
          initials: row.initials,
          size: 32,
          radius: 8,
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

/// The five seeded `UserTypes`; an unknown role falls back to neutral.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  static const _palette = <String, Color>{
    'admin': Color(0xFF6D3EDB),
    'work preparation': Color(0xFF9A6212),
    'finances': Color(0xFF107A4D),
    'project manager': Color(0xFFB5306E),
    'production worker': Color(0xFF2563EB),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
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
