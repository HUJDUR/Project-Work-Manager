import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/worker_summary.dart';
import '../providers/dashboard_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'widgets/summary_card.dart';

/// The shop floor's home screen: a greeting, what the signed-in worker has
/// booked today, and the same for the week — laid out as in
/// `docs/mockups/mobile/Dashboard.png`.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.providerFactory, this.onViewAllHours});

  /// Lets a test swap in a provider backed by fake data.
  final DashboardProvider Function()? providerFactory;

  /// "View all" on the week's card — the shell sends it to the My Hours tab.
  final VoidCallback? onViewAllHours;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? DashboardProvider())..load(),
      child: Consumer<DashboardProvider>(
        builder: (context, provider, _) {
          final summary = provider.summary;

          return switch (provider.status) {
            DashboardStatus.failed => _ErrorState(
                message: provider.errorMessage ??
                    'Your work could not be loaded.',
                onRetry: provider.load,
              ),
            DashboardStatus.ready when summary != null => _DashboardBody(
                name: provider.greetingName,
                summary: summary,
                onRefresh: provider.load,
                onViewAllHours: onViewAllHours,
              ),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.name,
    required this.summary,
    required this.onRefresh,
    this.onViewAllHours,
  });

  final String name;
  final WorkerSummary summary;
  final Future<void> Function() onRefresh;
  final VoidCallback? onViewAllHours;

  @override
  Widget build(BuildContext context) {
    // Pull to refresh: there is no Refresh button on a phone, and the numbers
    // go stale the moment the worker books anything.
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          const SizedBox(height: 8),
          Text(
            'Hello, $name',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Here's an overview of your work today.",
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          SummaryCard(
            title: "Today's Summary",
            left: SummaryTile(
              icon: Icons.schedule_outlined,
              label: 'Work Hours Today',
              value: formatClockHours(summary.todayHours),
            ),
            right: SummaryTile(
              icon: Icons.work_outline,
              label: 'Projects Worked On',
              value: formatCount(summary.todayProjects),
            ),
          ),
          const SizedBox(height: AppSpacing.gap),
          SummaryCard(
            title: 'This Week',
            actionLabel: onViewAllHours == null ? null : 'View all',
            onAction: onViewAllHours,
            left: SummaryTile(
              icon: Icons.bar_chart_outlined,
              label: 'Total Work Hours',
              value: formatClockHours(summary.weekHours),
            ),
            right: SummaryTile(
              icon: Icons.folder_outlined,
              label: 'Projects Worked On',
              value: formatCount(summary.weekProjects),
            ),
          ),
        ],
      ),
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 38, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'Your work could not be loaded',
              textAlign: TextAlign.center,
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
