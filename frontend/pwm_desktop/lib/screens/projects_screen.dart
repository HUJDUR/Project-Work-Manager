import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/projects_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'project_details_screen.dart';
import 'project_overview_screen.dart';
import 'widgets/clear_filters_button.dart';
import 'widgets/projects_table.dart';
import 'widgets/search_field.dart';
import 'widgets/summary_card.dart';

/// Every project with its customer, category and status, laid out as in
/// `docs/mockups/desktop/Projects.png`.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key, this.providerFactory});

  /// Lets a test swap in a provider backed by fake data.
  final ProjectsProvider Function()? providerFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? ProjectsProvider())..load(),
      child: Consumer<ProjectsProvider>(
        builder: (context, provider, _) {
          return switch (provider.status) {
            ProjectsStatusState.failed => _ErrorState(
                message: provider.errorMessage ?? 'Projects could not be loaded.',
                onRetry: provider.load,
              ),
            ProjectsStatusState.ready => _Body(provider: provider),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

/// Raises a new project - the only way into [ProjectDetailsScreen] left in the
/// projects screen itself now; an existing project opens on its read-only
/// overview instead, via [openProjectOverview].
Future<void> openProjectDetails(
  BuildContext context,
  ProjectsProvider provider, {
  ProjectRow? row,
}) async {
  final result = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => ProjectDetailsScreen(provider: provider, row: row),
    ),
  );

  if (result == 'reload') await provider.refresh();
}

/// Opens one project's read-only overview, laid out as in
/// `docs/mockups/desktop/Project details.png`. Editing happens from there, via
/// its own "Edit Project" button, so nothing here needs to refetch on return.
Future<void> openProjectOverview(
  BuildContext context,
  ProjectsProvider provider, {
  required ProjectRow row,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProjectOverviewScreen(provider: provider, row: row),
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final ProjectsProvider provider;

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
            child: ProjectsTable(
              provider: provider,
              onRowTap: (row) => openProjectOverview(context, provider, row: row),
            ),
          ),
        ],
      ),
    );
  }
}

/// Title on the left, the three counters from the mockup on the right. They
/// count every project, not the filtered page — they sit above the filters.
class _Header extends StatelessWidget {
  const _Header({required this.provider});

  static const _cardsWidth = 660.0;

  final ProjectsProvider provider;

  @override
  Widget build(BuildContext context) {
    final metrics = <SummaryMetric>[
      SummaryMetric(
        icon: Icons.folder_open_outlined,
        label: 'Active Projects',
        value: formatCount(provider.activeCount),
        caption: 'of ${formatCount(provider.totalCount)} total',
      ),
      SummaryMetric(
        icon: Icons.engineering_outlined,
        label: 'In Production',
        value: formatCount(provider.inProductionCount),
        caption: 'on the shop floor',
      ),
      SummaryMetric(
        icon: Icons.check_circle_outline,
        label: 'Delivered',
        value: formatCount(provider.deliveredCount),
        caption: 'handed over',
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Projects', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              SizedBox(height: 2),
              Text(
                'Overview of all projects',
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

  final ProjectsProvider provider;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    widget.provider.clearFilters();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => widget.provider.setSearch(value));
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SearchField(
            controller: _searchController,
            hintText: 'Search projects...',
            onChanged: _onSearchChanged,
            onSubmitted: provider.setSearch,
            onClear: () {
              _debounce?.cancel();
              provider.setSearch('');
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int?>(
            initialValue: provider.statusId,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Status')),
              for (final ProjectStatusType status in provider.statusTypes)
                DropdownMenuItem(
                  value: status.id,
                  child: Text(status.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: provider.setStatus,
          ),
        ),
        const SizedBox(width: 12),
        ClearFiltersButton(hasFilters: provider.hasFilters, onPressed: _clearFilters),
        const Spacer(flex: 2),
        OutlinedButton.icon(
          onPressed: () => openProjectDetails(context, provider),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Project'),
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
              'Projects could not be loaded',
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
              // Default icon-button padding is asymmetric; this centers it.
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
