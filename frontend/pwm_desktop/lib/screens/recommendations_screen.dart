import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/recommendations_provider.dart';
import '../utils/app_theme.dart';

/// Project Resource Estimation, laid out as in
/// `docs/mockups/desktop/Recommendation.png`.
///
/// The screen is built; the estimator behind it is not. Pressing Estimate says
/// so rather than showing invented numbers — see [RecommendationsProvider].
class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key, this.providerFactory});

  /// Lets a test swap in a provider backed by fake data.
  final RecommendationsProvider Function()? providerFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? RecommendationsProvider())..load(),
      child: Consumer<RecommendationsProvider>(
        builder: (context, provider, _) {
          return switch (provider.status) {
            RecommendationsStatusState.failed => _ErrorState(
                message:
                    provider.errorMessage ?? 'Project types could not be loaded.',
                onRetry: provider.load,
              ),
            RecommendationsStatusState.ready => _Body(provider: provider),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final RecommendationsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(provider: provider),
          const SizedBox(height: AppSpacing.gap),
          _InputBar(provider: provider),
          const SizedBox(height: AppSpacing.gap),
          _MetricRow(),
          const SizedBox(height: AppSpacing.gap),
          Expanded(child: _WorkTypeTable(provider: provider)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.provider});

  final RecommendationsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Project Resource Estimation',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 2),
              Text(
                'Estimated hours, duration and workforce based on past projects.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: provider.canEstimate ? provider.estimate : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: BorderSide(color: AppColors.accent),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
          ),
          child: const Text('Estimate'),
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.provider});

  static const _decoration = InputDecoration(
    border: OutlineInputBorder(),
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
  );

  final RecommendationsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int?>(
            initialValue: provider.categoryId,
            isExpanded: true,
            decoration: _decoration,
            hint: const Text('Select project type'),
            items: [
              for (final ProjectCategory category in provider.categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: provider.setCategory,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: provider.setTonnes,
            decoration: _decoration.copyWith(hintText: 'Expected tonnage (t)'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            keyboardType: TextInputType.number,
            onChanged: provider.setWorkingDays,
            decoration: _decoration.copyWith(hintText: 'Deadline (working days)'),
          ),
        ),
      ],
    );
  }
}

/// The mockup's four cards. Every value reads as a dash until there is an
/// estimator to fill it in.
class _MetricRow extends StatelessWidget {
  const _MetricRow();

  static const _metrics = <(IconData, String, String)>[
    (Icons.schedule_outlined, 'Total Estimated Hours', 'across every work type'),
    (Icons.groups_outlined, 'Estimated Workers', 'to hit the deadline'),
    (Icons.calendar_month_outlined, 'Estimated Duration', 'working days'),
    (Icons.verified_outlined, 'Based On Projects', 'comparable past jobs'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, metric) in _metrics.indexed) ...[
          Expanded(
            child: _MetricCard(icon: metric.$1, label: metric.$2, caption: metric.$3),
          ),
          if (index < _metrics.length - 1) const SizedBox(width: AppSpacing.gap),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '—',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _WorkTypeTable extends StatelessWidget {
  const _WorkTypeTable({required this.provider});

  static const _columns = <(String, int)>[
    ('Work Type', 3),
    ('Distribution', 4),
    ('Estimated Hours', 2),
    ('Share', 1),
  ];

  final RecommendationsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                for (final (label, flex) in _columns)
                  Expanded(
                    flex: flex,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _EmptyState(asked: provider.asked)),
        ],
      ),
    );
  }
}

/// Says plainly that the estimate is not implemented rather than dressing the
/// screen up with numbers nothing produced.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.asked});

  final bool asked;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              asked ? Icons.hourglass_empty : Icons.insights_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              asked ? 'No estimate yet' : 'Nothing to estimate yet',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              asked
                  ? 'The estimator has not been built yet, so there are no hours '
                      'to break down. The screen is ready for it.'
                  : 'Pick a project type, an expected tonnage and a deadline, '
                      'then press Estimate.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'Project types could not be loaded',
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
