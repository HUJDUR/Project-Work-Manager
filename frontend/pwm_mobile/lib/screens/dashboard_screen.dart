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

          // Keyed off whether there is anything to show rather than off the
          // status: a refresh leaves the last numbers in place and says so on
          // the button, where switching on the status would blank the screen to
          // a spinner every time it is pressed. The full error state is for
          // having nothing at all; a refresh that fails over good data keeps
          // the data and reports itself in a banner.
          if (summary == null) {
            return provider.status == DashboardStatus.failed
                ? _ErrorState(
                    message: provider.errorMessage ??
                        'Your work could not be loaded.',
                    onRetry: provider.load,
                  )
                : const Center(child: CircularProgressIndicator());
          }

          return _DashboardBody(
            name: provider.greetingName,
            summary: summary,
            onRefresh: provider.load,
            isRefreshing: provider.isLoading,
            staleWarning: provider.status == DashboardStatus.failed
                ? provider.errorMessage ?? 'Could not refresh.'
                : null,
            onViewAllHours: onViewAllHours,
          );
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
    required this.isRefreshing,
    this.staleWarning,
    this.onViewAllHours,
  });

  final String name;
  final WorkerSummary summary;
  final Future<void> Function() onRefresh;
  final bool isRefreshing;

  /// Set when the last refresh failed and what is on screen is the previous
  /// answer — null while the numbers are current.
  final String? staleWarning;

  final VoidCallback? onViewAllHours;

  @override
  Widget build(BuildContext context) {
    // Pull to refresh as well as the button: the numbers go stale the moment
    // the worker books anything, and a pull is the gesture a phone expects.
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RefreshButton(
                onRefresh: onRefresh,
                isRefreshing: isRefreshing,
              ),
            ],
          ),
          if (staleWarning != null) ...[
            const SizedBox(height: 16),
            _StaleBanner(message: staleWarning!),
          ],
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

/// The refresh control, sat beside the greeting.
///
/// It keeps its footprint while it spins — the spinner is drawn at the icon's
/// size inside the same box — so the greeting beside it does not shift when it
/// is pressed.
class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onRefresh, required this.isRefreshing});

  static const double _size = 42;

  final Future<void> Function() onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Material(
        color: AppColors.accentSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
        clipBehavior: Clip.antiAlias,
        child: Tooltip(
          message: isRefreshing ? 'Refreshing' : 'Refresh',
          child: InkWell(
            // Null while it is already running, so a second tap cannot start a
            // load on top of the one in flight.
            onTap: isRefreshing ? null : onRefresh,
            child: Center(
              child: isRefreshing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : Icon(Icons.refresh, size: 21, color: AppColors.accent),
            ),
          ),
        ),
      ),
    );
  }
}

/// Says the figures below are the previous answer, when a refresh failed but
/// there was still something worth leaving on screen.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 17, color: AppColors.danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              "Showing what was last loaded. $message",
              style: TextStyle(fontSize: 12.5, color: AppColors.danger),
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
