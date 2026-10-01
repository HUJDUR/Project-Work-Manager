import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../providers/activities_provider.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/formatters.dart';
import '../utils/sarajevo_time.dart';
import 'widgets/activities_table.dart';
import 'widgets/clear_filters_button.dart';
import 'widgets/search_field.dart';

/// Every sign-in, sign-out, message and report run, across every account —
/// what an administrator reaches for when something needs tracing back to
/// whoever did it. `AppRoles` keeps this off the sidebar for anyone else, and
/// `ActivityLogController` refuses the call either way.
class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key, this.providerFactory});

  /// Lets a test swap in a provider backed by fake data.
  final ActivitiesProvider Function()? providerFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? ActivitiesProvider())..load(),
      child: Consumer<ActivitiesProvider>(
        builder: (context, provider, _) {
          return switch (provider.status) {
            ActivitiesStatusState.failed => _ErrorState(
                message: provider.errorMessage ?? 'Activities could not be loaded.',
                onRetry: provider.load,
              ),
            ActivitiesStatusState.ready => _Body(provider: provider),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final ActivitiesProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(),
          const SizedBox(height: AppSpacing.gap),
          _FilterBar(provider: provider),
          const SizedBox(height: AppSpacing.gap),
          Expanded(child: ActivitiesTable(provider: provider)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activities', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          'Every sign-in, message and report run, by whoever did it',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _FilterBar extends StatefulWidget {
  const _FilterBar({required this.provider});

  final ActivitiesProvider provider;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  final _searchController = TextEditingController();

  /// Each search asks the API, so typing waits for a pause first.
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => widget.provider.setSearch(value));
  }

  void _clearFilters() {
    _debounce?.cancel();
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
          child: SearchField(
            controller: _searchController,
            hintText: 'Search users...',
            onChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int?>(
            key: ValueKey(provider.activityTypeId),
            initialValue: provider.activityTypeId,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Activity')),
              for (final type in provider.activityTypes)
                DropdownMenuItem(
                  value: type.id,
                  child: Text(type.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: provider.setActivityType,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: _DateRangeField(provider: provider)),
        const SizedBox(width: 12),
        ClearFiltersButton(hasFilters: provider.hasFilters, onPressed: _clearFilters),
      ],
    );
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({required this.provider});

  final ActivitiesProvider provider;

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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
    final now = SarajevoTime.now();
    final picked = await pickDateRange(
      context,
      initialDateRange: provider.dateRange,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) provider.setDateRange(picked);
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
              'Activities could not be loaded',
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
