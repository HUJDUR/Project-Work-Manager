import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../providers/transports_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import 'excel_table_header.dart';
import 'table_pager.dart';

/// A state with no colour of its own.
const Color _neutral = Color(0xFF6B7280);

/// The breathing room between two columns of a row - matches the gap the
/// header already puts between its own cells.
const _columnGap = SizedBox(width: 16);

final _columns = <ExcelColumn<TransportRow>>[
  ExcelColumn(
    label: 'Transport No',
    flex: 3,
    sortKey: (row) => row.transportNo,
    filterValues: (row) => [row.transportNo],
  ),
  ExcelColumn(
    label: 'Load Date',
    flex: 2,
    // ISO sorts chronologically as plain text; the formatted date shown in
    // the filter checklist below does not.
    sortKey: (row) => row.loadDate.toIso8601String(),
    filterValues: (row) => [formatFullDate(row.loadDate)],
  ),
  ExcelColumn(
    label: 'Driver Name',
    flex: 2,
    sortKey: (row) => row.driverName,
    filterValues: (row) => [row.driverName],
  ),
  ExcelColumn(
    label: 'Driver Surname',
    flex: 2,
    sortKey: (row) => row.driverSurname,
    filterValues: (row) => [row.driverSurname],
  ),
  ExcelColumn(
    label: 'Registration',
    flex: 2,
    sortKey: (row) => row.vehicleRegistration,
    filterValues: (row) => [row.vehicleRegistration],
  ),
  ExcelColumn(
    label: 'Full Weight (kg)',
    flex: 2,
    sortKey: (row) => row.fullWeight.toString(),
    filterValues: (row) => [formatCount(row.fullWeight)],
  ),
  ExcelColumn(
    label: 'Empty Weight (kg)',
    flex: 2,
    sortKey: (row) => row.emptyWeight.toString(),
    filterValues: (row) => [formatCount(row.emptyWeight)],
  ),
  ExcelColumn(
    label: 'Status',
    flex: 2,
    sortKey: (row) => row.statusName,
    filterValues: (row) => [row.statusName],
  ),
];

/// The transports list with Excel's own AutoFilter, the same pattern the
/// Workers screen tried first: every header sorts on a click and carries a
/// checklist of that column's values to filter down to, over the whole
/// matching set - what the search box, status dropdown and date range leave a
/// match - rather than the page of eight [TransportsProvider] otherwise pages
/// through. This widget reads that whole set via [TransportsProvider.
/// loadAllRows] and paginates, sorts and filters it here instead.
class TransportsTable extends StatefulWidget {
  const TransportsTable({super.key, required this.provider, required this.onRowTap});

  final TransportsProvider provider;

  /// Opens the load in the details screen.
  final ValueChanged<TransportRow> onRowTap;

  @override
  State<TransportsTable> createState() => _TransportsTableState();
}

enum _LoadStatus { loading, ready, failed }

class _TransportsTableState extends State<TransportsTable>
    with ExcelTableState<TransportRow, TransportsTable> {
  _LoadStatus _status = _LoadStatus.loading;
  List<TransportRow> _allRows = const [];

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant TransportsTable oldWidget) {
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

  /// The search box, status dropdown and date range each notify the provider
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
        ? const <TransportRow>[]
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
          ExcelHeaderRow<TransportRow>(
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
                    'Could not load the full transport list.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              _ => pageRows.isEmpty
                  ? _NoRows()
                  : ListView.separated(
                      itemCount: pageRows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => _TransportRowTile(
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

class _TransportRowTile extends StatelessWidget {
  const _TransportRowTile({required this.row, required this.onTap});

  final TransportRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(flex: _columns[0].flex, child: _Transport(row: row)),
            _columnGap,
            Expanded(flex: _columns[1].flex, child: _Cell(formatFullDate(row.loadDate))),
            _columnGap,
            Expanded(flex: _columns[2].flex, child: _Cell(row.driverName)),
            _columnGap,
            Expanded(flex: _columns[3].flex, child: _Cell(row.driverSurname)),
            _columnGap,
            Expanded(flex: _columns[4].flex, child: _Cell(row.vehicleRegistration)),
            _columnGap,
            Expanded(
              flex: _columns[5].flex,
              child: _Cell(
                formatCount(row.fullWeight),
                // What is actually on the truck, which is what the shop bills.
                caption: '${formatTonnes(row.netWeight)} net',
              ),
            ),
            _columnGap,
            Expanded(
              flex: _columns[6].flex,
              child: _Cell(formatCount(row.emptyWeight)),
            ),
            _columnGap,
            Expanded(
              flex: _columns[7].flex,
              child: TruckLoadStatusChip(status: row.statusName),
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

class _Transport extends StatelessWidget {
  const _Transport({required this.row});

  final TransportRow row;

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
          child: Icon(Icons.local_shipping_outlined,
              size: 17, color: AppColors.accent),
        ),
        SizedBox(width: 10),
        Expanded(child: _Cell(row.transportNo, caption: row.carrierName)),
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

/// Colours the seeded `TruckLoadStatusTypes` by how far along a load is; an
/// unknown name falls back to neutral rather than guessing.
class TruckLoadStatusChip extends StatelessWidget {
  const TruckLoadStatusChip({super.key, required this.status});

  /// One colour per state; the background is derived from it so the chip works
  /// on a white card and a dark one alike.
  static const _palette = <String, Color>{
    'ordered': _neutral,
    'delivered': Color(0xFF2563EB),
    'finished': Color(0xFF107A4D),
    'rejected': Color(0xFFB91C1C),
  };

  final String status;

  static (Color background, Color foreground) colorsFor(String status) =>
      AppColors.chip(_palette[status.toLowerCase()] ?? _neutral);

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = colorsFor(status);

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
        'No transports match the current filters.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}
