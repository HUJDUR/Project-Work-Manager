import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/work_hours_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'widgets/add_work_hours_dialog.dart';
import 'widgets/summary_card.dart';
import 'widgets/work_hours_table.dart';

/// Every recorded work hour, laid out as in `docs/mockups/desktop/Hours.png`.
class WorkHoursScreen extends StatelessWidget {
  const WorkHoursScreen({super.key, this.providerFactory});

  /// Lets a test swap in a provider backed by fake data.
  final WorkHoursProvider Function()? providerFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? WorkHoursProvider())..load(),
      child: Consumer<WorkHoursProvider>(
        builder: (context, provider, _) {
          return switch (provider.status) {
            WorkHoursStatusState.failed => _ErrorState(
                message: provider.errorMessage ?? 'Work hours could not be loaded.',
                onRetry: provider.load,
              ),
            WorkHoursStatusState.ready => _Body(provider: provider),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final WorkHoursProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(provider: provider),
          const SizedBox(height: AppSpacing.gap),
          _FilterBar(provider: provider),
          const SizedBox(height: AppSpacing.gap),
          _SummaryRow(provider: provider),
          const SizedBox(height: AppSpacing.gap),
          Expanded(child: WorkHoursTable(entries: provider.entries)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.provider});

  final WorkHoursProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Work Hours', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            SizedBox(height: 2),
            Text(
              'Overview of all recorded work hours',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () => AddWorkHoursDialog.show(context, provider),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Work Hours'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.provider});

  final WorkHoursProvider provider;

  @override
  Widget build(BuildContext context) {
    final entries = provider.entries;
    final metrics = <SummaryMetric>[
      SummaryMetric(
        icon: Icons.schedule_outlined,
        label: 'Total Hours',
        value: formatHours(provider.totalHours),
        caption: '${entries.length} entries',
      ),
      SummaryMetric(
        icon: Icons.check_circle_outline,
        label: 'Regular Hours',
        value: formatHours(provider.regularHours),
        caption: 'first ${WorkHoursProvider.regularHoursPerDay.toInt()} h of a day',
      ),
      SummaryMetric(
        icon: Icons.more_time_outlined,
        label: 'Overtime Hours',
        value: formatHours(provider.overtimeHours),
        caption: 'beyond ${WorkHoursProvider.regularHoursPerDay.toInt()} h of a day',
      ),
      SummaryMetric(
        icon: Icons.groups_outlined,
        label: 'Workers',
        value: formatCount(provider.workerCount),
        caption: 'with booked hours',
      ),
    ];

    return Row(
      children: [
        for (final metric in metrics) ...[
          Expanded(child: SummaryCard(metric: metric)),
          if (metric != metrics.last) const SizedBox(width: AppSpacing.gap),
        ],
      ],
    );
  }
}

class _FilterBar extends StatefulWidget {
  const _FilterBar({required this.provider});

  final WorkHoursProvider provider;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    if (_searchController.text != provider.search) {
      _searchController.text = provider.search;
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            onChanged: provider.setSearch,
            decoration: const InputDecoration(
              hintText: 'Search workers...',
              prefixIcon: Icon(Icons.search, size: 20),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int?>(
            initialValue: provider.projectId,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Projects')),
              for (final Project project in provider.projects)
                DropdownMenuItem(
                  value: project.id,
                  child: Text(project.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: provider.setProject,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: _DateRangeField(provider: provider)),
        const SizedBox(width: 12),
        _FilterMenu(provider: provider),
      ],
    );
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({required this.provider});

  final WorkHoursProvider provider;

  @override
  Widget build(BuildContext context) {
    final range = provider.dateRange;
    final label = range == null
        ? 'Select date range'
        : '${formatDate(range.start)} - ${formatFullDate(range.end)}';

    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          isDense: true,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          suffixIcon: range == null
              ? null
              : IconButton(
                  tooltip: 'Clear date range',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => provider.setDateRange(null),
                ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: range == null ? AppColors.textMuted : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: provider.dateRange,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) provider.setDateRange(picked);
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({required this.provider});

  final WorkHoursProvider provider;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More filters',
      position: PopupMenuPosition.under,
      icon: Icon(
        Icons.filter_alt_outlined,
        color: provider.hasFilters ? AppColors.accent : AppColors.textSecondary,
      ),
      style: IconButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 'overtime',
          checked: provider.overtimeOnly,
          child: const Text('Overtime only'),
        ),
        CheckedPopupMenuItem(
          value: 'inProgress',
          checked: provider.inProgressOnly,
          child: const Text('In progress only'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'clear',
          enabled: provider.hasFilters,
          child: const Text('Clear filters'),
        ),
      ],
      onSelected: (value) => switch (value) {
        'overtime' => provider.setOvertimeOnly(!provider.overtimeOnly),
        'inProgress' => provider.setInProgressOnly(!provider.inProgressOnly),
        _ => provider.clearFilters(),
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
            const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'Work hours could not be loaded',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
