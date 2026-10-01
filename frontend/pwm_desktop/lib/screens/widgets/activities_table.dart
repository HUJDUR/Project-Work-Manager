import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../providers/activities_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import 'sort_header.dart';
import 'table_pager.dart';

/// The breathing room between two columns of a row - matches the gap the
/// header already puts between its own cells.
const _columnGap = SizedBox(width: 16);

/// Room for the header's own trailing space, so a row without a chevron of
/// its own still lines its last column up under the header.
const _trailingWidth = 32.0;

const _columns = <SortColumn>[
  SortColumn(label: 'User', flex: 3, sortKey: 'User'),
  SortColumn(label: 'Activity', flex: 4, sortKey: 'Activity'),
  SortColumn(label: 'Date', flex: 3, sortKey: 'Date'),
];

/// One page of the activity log as [ActivitiesProvider] holds it. The API
/// filters, sorts and pages, so a header click and the pager both go back to it.
class ActivitiesTable extends StatelessWidget {
  const ActivitiesTable({super.key, required this.provider});

  final ActivitiesProvider provider;

  @override
  Widget build(BuildContext context) {
    final rows = provider.rows;

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
                    itemBuilder: (context, index) => _ActivityRowTile(row: rows[index]),
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

/// Not wrapped in an `InkWell`: there is no details screen to open, an
/// activity is just a fact of record.
class _ActivityRowTile extends StatelessWidget {
  const _ActivityRowTile({required this.row});

  final ActivityRow row;

  @override
  Widget build(BuildContext context) {
    final local = row.date;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: _columns[0].flex, child: _User(row: row)),
          _columnGap,
          Expanded(flex: _columns[1].flex, child: _Cell(row.activityTypeName)),
          _columnGap,
          Expanded(
            flex: _columns[2].flex,
            child: _Cell(formatFullDate(local), caption: formatTime(local)),
          ),
          const SizedBox(width: _trailingWidth),
        ],
      ),
    );
  }
}

class _User extends StatelessWidget {
  const _User({required this.row});

  final ActivityRow row;

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
            row.userInitials,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _Cell(row.userName)),
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

class _NoRows extends StatelessWidget {
  const _NoRows();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No activity matches the current filters.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}
