import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dashboard_data.dart';
import '../providers/dashboard_provider.dart';
import '../utils/app_theme.dart';
import 'widgets/hours_by_operation_chart.dart';
import 'widgets/hours_by_project_chart.dart';
import 'widgets/list_panels.dart';
import 'widgets/summary_card.dart';

/// The admin home screen: a summary row, two charts and three recent-activity
/// lists, laid out as in `docs/mockups/desktop/Dashboard.png`.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.providerFactory});

  static const _chartRowHeight = 340.0;
  static const _listRowHeight = 384.0;

  /// Lets a test swap in a provider backed by fake data.
  final DashboardProvider Function()? providerFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? DashboardProvider())..load(),
      child: Consumer<DashboardProvider>(
        builder: (context, provider, _) {
          final data = provider.data;

          return switch (provider.status) {
            DashboardStatus.failed => _ErrorState(
                message: provider.errorMessage ?? 'The dashboard could not be loaded.',
                onRetry: provider.load,
              ),
            DashboardStatus.ready when data != null =>
              _DashboardBody(data: data, onRefresh: provider.load),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data, required this.onRefresh});

  final DashboardData data;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(onRefresh: onRefresh),
          const SizedBox(height: AppSpacing.gap),
          _SummaryRow(metrics: data.metrics),
          const SizedBox(height: AppSpacing.gap),
          SizedBox(
            height: DashboardScreen._chartRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: HoursByProjectChart(
                    slices: data.hoursByProject,
                    windowDays: data.windowDays,
                  ),
                ),
                const SizedBox(width: AppSpacing.gap),
                Expanded(
                  child: HoursByOperationChart(
                    slices: data.hoursByOperation,
                    windowDays: data.windowDays,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gap),
          SizedBox(
            height: DashboardScreen._listRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: LatestWorkPanel(entries: data.recentWork)),
                const SizedBox(width: AppSpacing.gap),
                Expanded(child: TransportPanel(entries: data.recentTransports)),
                const SizedBox(width: AppSpacing.gap),
                Expanded(child: ActivityPanel(entries: data.recentActivity)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 2),
            Text(
              'Key indicators across projects, hours and transport',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

/// The cards fill the row when they all fit; when the window is too narrow for
/// that they wrap, and the count per row is levelled out so the last row is not
/// left with a single stranded card (5 cards wrap to 3 + 2, never 4 + 1).
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.metrics});

  static const _minCardWidth = 210.0;

  final List<SummaryMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fitPerRow =
            (constraints.maxWidth / _minCardWidth).floor().clamp(1, metrics.length);
        final rows = (metrics.length / fitPerRow).ceil();
        final perRow = (metrics.length / rows).ceil();
        final cardWidth =
            (constraints.maxWidth - AppSpacing.gap * (perRow - 1)) / perRow;

        return Wrap(
          spacing: AppSpacing.gap,
          runSpacing: AppSpacing.gap,
          children: [
            for (final metric in metrics)
              SizedBox(width: cardWidth, child: SummaryCard(metric: metric)),
          ],
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'The dashboard could not be loaded',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
