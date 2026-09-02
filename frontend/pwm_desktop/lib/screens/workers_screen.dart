import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/workers_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'widgets/summary_card.dart';
import 'widgets/workers_table.dart';
import 'worker_details_screen.dart';

/// Everyone with an account: who they are, what they do and — for the shop
/// floor — which operations they are qualified for. No mockup; it follows the
/// projects screen.
class WorkersScreen extends StatelessWidget {
  const WorkersScreen({super.key, this.providerFactory});

  /// Lets a test swap in a provider backed by fake data.
  final WorkersProvider Function()? providerFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? WorkersProvider())..load(),
      child: Consumer<WorkersProvider>(
        builder: (context, provider, _) {
          return switch (provider.status) {
            WorkersStatusState.failed => _ErrorState(
                message: provider.errorMessage ?? 'Workers could not be loaded.',
                onRetry: provider.load,
              ),
            WorkersStatusState.ready => _Body(provider: provider),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

/// Opens one account - or a blank form when [row] is null - and refetches once
/// the details screen reports it wrote something.
Future<void> openWorkerDetails(
  BuildContext context,
  WorkersProvider provider, {
  WorkerRow? row,
}) async {
  final result = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => WorkerDetailsScreen(provider: provider, row: row),
    ),
  );

  if (result == 'reload') await provider.refresh();
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final WorkersProvider provider;

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
          Expanded(
            child: WorkersTable(
              rows: provider.rows,
              page: provider.page,
              pageCount: provider.pageCount,
              onPageChanged: provider.setPage,
              onRowTap: (row) => openWorkerDetails(context, provider, row: row),
            ),
          ),
        ],
      ),
    );
  }
}

/// Title on the left, the three counters on the right. They count the whole
/// staff list rather than the filtered page, as on the projects screen.
class _Header extends StatelessWidget {
  const _Header({required this.provider});

  static const _cardsWidth = 660.0;

  final WorkersProvider provider;

  @override
  Widget build(BuildContext context) {
    final metrics = <SummaryMetric>[
      SummaryMetric(
        icon: Icons.groups_outlined,
        label: 'Current Workers',
        value: formatCount(provider.currentCount),
        caption: 'of ${formatCount(provider.headcount)} accounts',
      ),
      SummaryMetric(
        icon: Icons.engineering_outlined,
        label: 'In Production',
        value: formatCount(provider.productionCount),
        caption: 'on the shop floor',
      ),
      SummaryMetric(
        icon: Icons.badge_outlined,
        label: 'Administration',
        value: formatCount(provider.administrationCount),
        caption: 'managers and admins',
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Workers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              SizedBox(height: 2),
              Text(
                'Everyone working in the company',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _cardsWidth),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final metric in metrics) ...[
                Flexible(child: SummaryCard(metric: metric)),
                if (metric != metrics.last) const SizedBox(width: AppSpacing.gap),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatefulWidget {
  const _FilterBar({required this.provider});

  final WorkersProvider provider;

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

  void _clearFilters() {
    _searchController.clear();
    widget.provider.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            onSubmitted: provider.setSearch,
            decoration: InputDecoration(
              hintText: 'Search workers...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.arrow_forward, size: 18),
                onPressed: () => provider.setSearch(_searchController.text),
              ),
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int?>(
            initialValue: provider.roleId,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Roles')),
              for (final UserType role in provider.roles)
                DropdownMenuItem(
                  value: role.id,
                  child: Text(role.type, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: provider.setRole,
          ),
        ),
        const SizedBox(width: 12),
        _FilterMenu(provider: provider, onClear: _clearFilters),
        const Spacer(flex: 2),
        OutlinedButton.icon(
          onPressed: () => openWorkerDetails(context, provider),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Worker'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: BorderSide(color: AppColors.accent),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          ),
        ),
      ],
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({required this.provider, required this.onClear});

  final WorkersProvider provider;
  final VoidCallback onClear;

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
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 'active',
          checked: provider.activeOnly,
          child: const Text('Current workers only'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'clear',
          enabled: provider.hasFilters,
          child: const Text('Clear filters'),
        ),
      ],
      onSelected: (value) => switch (value) {
        'active' => provider.setActiveOnly(!provider.activeOnly),
        _ => onClear(),
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
              'Workers could not be loaded',
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
