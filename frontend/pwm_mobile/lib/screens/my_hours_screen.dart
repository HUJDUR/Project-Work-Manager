import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/work_day.dart';
import '../providers/my_hours_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/formatters.dart';
import 'widgets/trend_card.dart';
import 'work_day_screen.dart';

/// My Work Hours: the signed-in worker's own bookings for a chosen period,
/// laid out as in `docs/mockups/mobile/My hours.png` — a period picker, two
/// metric cards with trend lines, then one row per day.
class MyHoursScreen extends StatelessWidget {
  const MyHoursScreen({super.key, this.providerFactory});

  /// Lets a test swap in a provider backed by fake data.
  final MyHoursProvider Function()? providerFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? MyHoursProvider())..load(),
      child: Consumer<MyHoursProvider>(
        builder: (context, provider, _) => _Body(provider: provider),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final MyHoursProvider provider;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          const SizedBox(height: 4),
          Text(
            'My Work Hours',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Overview of your logged work hours',
            style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          _PeriodPicker(provider: provider),
          const SizedBox(height: AppSpacing.gap),
          _Metrics(provider: provider),
          const SizedBox(height: 26),
          Text(
            'Work Hour Entries',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ..._entries(context),
        ],
      ),
    );
  }

  List<Widget> _entries(BuildContext context) {
    return switch (provider.status) {
      MyHoursStatus.failed => [
          _Message(
            icon: Icons.cloud_off_outlined,
            title: 'Your hours could not be loaded',
            detail: provider.errorMessage ?? '',
            onRetry: provider.load,
          ),
        ],
      MyHoursStatus.ready when provider.days.isEmpty => [
          _Message(
            icon: Icons.event_busy_outlined,
            title: 'Nothing booked ${provider.period.label.toLowerCase()}',
            detail: 'Hours you book from Clock In will show up here.',
          ),
        ],
      MyHoursStatus.ready => [
          for (final day in provider.days)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DayRow(day: day, provider: provider),
            ),
          if (provider.hasMore) _LoadMoreButton(provider: provider),
        ],
      _ => [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
    };
  }
}

/// The next page of days, under the ones already showing.
class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.provider});

  final MyHoursProvider provider;

  Future<void> _loadMore(BuildContext context) async {
    try {
      await provider.loadMore();
    } on ApiClientException catch (error) {
      if (context.mounted) showErrorSnackBar(context, error.message);
    } catch (_) {
      if (context.mounted) showErrorSnackBar(context, 'The server could not be reached.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 46,
        child: OutlinedButton(
          onPressed: provider.isLoadingMore ? null : () => _loadMore(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: BorderSide(color: AppColors.accent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: provider.isLoadingMore
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                )
              : const Text('Load more days'),
        ),
      ),
    );
  }
}

/// The mockup's dropdown: a bordered field with a calendar leading it.
class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.provider});

  final MyHoursProvider provider;

  @override
  Widget build(BuildContext context) {
    final range = provider.range;

    return DropdownButtonFormField<HoursPeriod>(
      initialValue: provider.period,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
      decoration: InputDecoration(
        prefixIcon: Icon(
          Icons.calendar_today_outlined,
          size: 19,
          color: AppColors.textPrimary,
        ),
      ),
      // Disabled while a load is in flight, so a second pick cannot race the
      // first — the answers would arrive in whatever order the API sends them.
      onChanged: provider.isLoading
          ? null
          : (period) {
              if (period != null) provider.setPeriod(period);
            },
      selectedItemBuilder: (context) => [
        for (final period in HoursPeriod.values)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              // The dates the period stands for, so "This week" is not the only
              // thing telling the worker what they are looking at. `to` is
              // exclusive, hence the day back.
              '${period.label}  ·  ${formatDate(range.from)} - '
              '${formatDate(range.to.subtract(const Duration(days: 1)))}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
      ],
      items: [
        for (final period in HoursPeriod.values)
          DropdownMenuItem(value: period, child: Text(period.label)),
      ],
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.provider});

  final MyHoursProvider provider;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TrendCard(
              icon: Icons.schedule_outlined,
              title: 'Total Hours',
              value: formatHoursValue(provider.totalHours),
              unit: 'hrs',
              trend: provider.hoursTrend,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TrendCard(
              icon: Icons.folder_outlined,
              title: 'Projects Worked On',
              value: formatCount(provider.projectCount),
              unit: 'projects',
              trend: provider.projectsTrend,
            ),
          ),
        ],
      ),
    );
  }
}

/// One day: the date, what was booked against it, and the way into the detail.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.provider});

  final WorkDay day;
  final MyHoursProvider provider;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatDayLabel(day.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _Tag(text: formatClockHours(day.hours)),
                    _Tag(
                      text: day.projectCount == 1
                          ? '1 project'
                          : '${day.projectCount} projects',
                    ),
                    if (day.hasOpenBlock) _Tag(text: 'In progress', accent: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ViewEntriesButton(day: day, provider: provider),
        ],
      ),
    );
  }
}

class _ViewEntriesButton extends StatelessWidget {
  const _ViewEntriesButton({required this.day, required this.provider});

  final WorkDay day;
  final MyHoursProvider provider;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => Navigator.of(context, rootNavigator: true).push(
        // The root navigator, because the shell's bottom bar is not a per-tab
        // navigator — a day covers the whole screen and carries its own way back.
        MaterialPageRoute(
          builder: (_) => WorkDayScreen(day: day, provider: provider),
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: BorderSide(color: AppColors.accent),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'View entries',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent ? AppColors.accentSoft : AppColors.fieldFill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: accent ? AppColors.accent : AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Covers the empty period and the failed load, which differ only in wording
/// and whether there is anything to retry.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}
