import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/transports_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import 'transport_details_screen.dart';
import 'widgets/transports_table.dart';

/// Every truck load with its carrier, driver and weights, laid out as in
/// `docs/mockups/desktop/Transports.png`.
class TransportScreen extends StatelessWidget {
  const TransportScreen({super.key, this.providerFactory});

  /// Lets a test swap in a provider backed by fake data.
  final TransportsProvider Function()? providerFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? TransportsProvider())..load(),
      child: Consumer<TransportsProvider>(
        builder: (context, provider, _) {
          return switch (provider.status) {
            TransportsStatusState.failed => _ErrorState(
                message:
                    provider.errorMessage ?? 'Transports could not be loaded.',
                onRetry: provider.load,
              ),
            TransportsStatusState.ready => _Body(provider: provider),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

/// Opens one load — or a blank form when [row] is null — and refetches once the
/// details screen reports it wrote something.
Future<void> openTransportDetails(
  BuildContext context,
  TransportsProvider provider, {
  TransportRow? row,
}) async {
  final result = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => TransportDetailsScreen(provider: provider, row: row),
    ),
  );

  if (result == 'reload') await provider.refresh();
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final TransportsProvider provider;

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
            child: TransportsTable(
              rows: provider.rows,
              page: provider.page,
              pageCount: provider.pageCount,
              onPageChanged: provider.setPage,
              onRowTap: (row) => openTransportDetails(context, provider, row: row),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.provider});

  final TransportsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transport Overview',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 2),
            Text(
              'Overview of all transport operations',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () => openTransportDetails(context, provider),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Transport'),
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

class _FilterBar extends StatefulWidget {
  const _FilterBar({required this.provider});

  final TransportsProvider provider;

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
            // A search costs a request, so it applies on Enter or the arrow.
            onSubmitted: provider.setSearch,
            decoration: InputDecoration(
              hintText: 'Search transports...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.arrow_forward, size: 18),
                onPressed: () => provider.setSearch(_searchController.text),
              ),
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            ),
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
              for (final TruckLoadStatusType status in provider.statusTypes)
                DropdownMenuItem(
                  value: status.id,
                  child: Text(status.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: provider.setStatus,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: _DateRangeField(provider: provider)),
        const SizedBox(width: 12),
        _FilterMenu(provider: provider, onClear: _clearFilters),
      ],
    );
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({required this.provider});

  final TransportsProvider provider;

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
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: provider.dateRange,
      firstDate: DateTime(now.year - 2),
      // A load can be planned ahead, so the range reaches into next year.
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) provider.setDateRange(picked);
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({required this.provider, required this.onClear});

  final TransportsProvider provider;
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
        PopupMenuItem(
          value: 'clear',
          enabled: provider.hasFilters,
          child: const Text('Clear filters'),
        ),
      ],
      onSelected: (_) => onClear(),
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
              'Transports could not be loaded',
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
