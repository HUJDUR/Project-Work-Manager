import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import 'table_pager.dart';

const _columns = <_Column>[
  _Column('Transport No', 3),
  _Column('Load Date', 2),
  _Column('Driver Name', 2),
  _Column('Driver Surname', 2),
  _Column('Registration', 2),
  _Column('Full Weight (kg)', 2),
  _Column('Empty Weight (kg)', 2),
  _Column('Status', 2),
];

/// A state with no colour of its own.
const Color _neutral = Color(0xFF6B7280);

class _Column {
  const _Column(this.label, this.flex);

  final String label;
  final int flex;
}

class TransportsTable extends StatelessWidget {
  const TransportsTable({
    super.key,
    required this.rows,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
    required this.onRowTap,
  });

  final List<TransportRow> rows;
  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  /// Opens the load in the details screen.
  final ValueChanged<TransportRow> onRowTap;

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
                    itemBuilder: (context, index) => _TransportRowTile(
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
            Expanded(flex: _columns[1].flex, child: _Cell(formatFullDate(row.loadDate))),
            Expanded(flex: _columns[2].flex, child: _Cell(row.driverName)),
            Expanded(flex: _columns[3].flex, child: _Cell(row.driverSurname)),
            Expanded(flex: _columns[4].flex, child: _Cell(row.vehicleRegistration)),
            Expanded(
              flex: _columns[5].flex,
              child: _Cell(
                formatCount(row.fullWeight),
                // What is actually on the truck, which is what the shop bills.
                caption: '${formatTonnes(row.netWeight)} net',
              ),
            ),
            Expanded(
              flex: _columns[6].flex,
              child: _Cell(formatCount(row.emptyWeight)),
            ),
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
    'in transit': Color(0xFF2563EB),
    'delivered': Color(0xFF6D3EDB),
    'finished': Color(0xFF107A4D),
  };

  final String status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) =
        AppColors.chip(_palette[status.toLowerCase()] ?? _neutral);

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
