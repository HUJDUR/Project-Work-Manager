import '../models/models.dart';
import '../providers/monthly_reports_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'monthly_report_details_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'widgets/table_pager.dart';

/// Every month's booked hours, newest first - admins and project managers.
class MonthlyReportsScreen extends StatelessWidget {
  const MonthlyReportsScreen({super.key, this.providerFactory, this.detailsBuilder});

  /// Lets a test swap in a provider backed by fake data.
  final MonthlyReportsProvider Function()? providerFactory;

  /// Lets a test open the details on fake data too.
  final Widget Function(MonthlyReportsProvider provider, MonthlyHourReport report)?
      detailsBuilder;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? MonthlyReportsProvider())..load(),
      child: Consumer<MonthlyReportsProvider>(
        builder: (context, provider, _) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(provider: provider),
                const SizedBox(height: AppSpacing.gap),
                Expanded(child: _content(context, provider)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _open(BuildContext context, MonthlyReportsProvider provider, MonthlyHourReport report) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            detailsBuilder?.call(provider, report) ??
            MonthlyReportDetailsScreen(api: provider.api, report: report),
      ),
    );
  }

  Widget _content(BuildContext context, MonthlyReportsProvider provider) {
    switch (provider.status) {
      case MonthlyReportsStatus.failed:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.errorMessage ?? 'Monthly reports could not be loaded.'),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: provider.load, child: const Text('Retry')),
            ],
          ),
        );
      case MonthlyReportsStatus.ready:
        return Column(
          children: [
            Expanded(
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _TableHeader(),
                    Divider(height: 1, color: AppColors.border),
                    Expanded(
                      child: provider.months.isEmpty
                          ? Center(
                              child: Text(
                                'No hours have been booked in this period.',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            )
                          : ListView.separated(
                              itemCount: provider.months.length,
                              separatorBuilder: (_, _) =>
                                  Divider(height: 1, color: AppColors.border),
                              itemBuilder: (context, index) {
                                final report = provider.months[index];
                                return _MonthRow(
                                  report: report,
                                  onTap: () => _open(context, provider, report),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            if (provider.pageCount > 1)
              TablePager(
                page: provider.page,
                pageCount: provider.pageCount,
                onPageChanged: provider.setPage,
              ),
          ],
        );
      default:
        return const Center(child: CircularProgressIndicator());
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.provider});

  final MonthlyReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Monthly Reports',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                'Hours booked each month, split into regular and overtime',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<int?>(
            key: const ValueKey('monthly-reports-year'),
            initialValue: provider.year,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All years')),
              for (final year in provider.years)
                DropdownMenuItem(value: year, child: Text('$year')),
            ],
            onChanged: provider.setYear,
          ),
        ),
      ],
    );
  }
}

const _columnFlex = [4, 2, 2, 2, 2];

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['Month', 'Workers', 'Regular', 'Overtime', 'Total'];
    final style = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    );

    // The right inset matches a row's chevron, so the figures line up.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 48, 14),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              flex: _columnFlex[i],
              child: Text(
                labels[i],
                textAlign: i == 0 ? TextAlign.start : TextAlign.end,
                style: style,
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.report, required this.onTap});

  final MonthlyHourReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final values = [
      formatCount(report.workerCount),
      formatHours(report.regularHours),
      formatHours(report.overtimeHours),
      formatHours(report.totalHours),
    ];

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
        child: Row(
          children: [
            Expanded(
              flex: _columnFlex[0],
              child: Row(
                children: [
                  Text(
                    formatMonth(report.year, report.month),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (MonthlyReportsProvider.isInProgress(report)) ...[
                    const SizedBox(width: 10),
                    InProgressChip(),
                  ],
                ],
              ),
            ),
            for (var i = 0; i < values.length; i++)
              Expanded(
                flex: _columnFlex[i + 1],
                child: Text(
                  values[i],
                  textAlign: TextAlign.end,
                  style: i == values.length - 1
                      ? const TextStyle(fontWeight: FontWeight.w600)
                      : null,
                ),
              ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// The month still being booked: its figures will keep moving.
class InProgressChip extends StatelessWidget {
  const InProgressChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        border: Border.all(color: AppColors.warningBorder),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'In progress',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.warning,
        ),
      ),
    );
  }
}
