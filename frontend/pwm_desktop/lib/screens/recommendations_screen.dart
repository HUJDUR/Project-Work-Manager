import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/recommendations_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

/// Project Resource Estimation, laid out as in
/// `docs/mockups/desktop/Recommendation.png`.
///
/// A linear regression per work type, fitted on the API against past delivered
/// projects of the picked category, is what fills the cards and the table -
/// see `RecommendationService`. This screen only asks for the three inputs and
/// renders whatever comes back.
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
          _MetricRow(provider: provider),
          if (provider.explanation != null) ...[
            const SizedBox(height: AppSpacing.gap),
            _ExplanationBanner(text: provider.explanation!),
          ],
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
        Tooltip(
          message: provider.canEstimate
              ? 'Estimate'
              : 'Pick a project type, an expected tonnage and a deadline first.',
          child: OutlinedButton(
            onPressed: provider.canEstimate && !provider.estimating
                ? provider.estimate
                : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
            ),
            child: provider.estimating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Estimate'),
          ),
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

/// The mockup's four cards. Every value reads as a dash until an estimate
/// comes back.
class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.provider});

  final RecommendationsProvider provider;

  @override
  Widget build(BuildContext context) {
    final hasEstimate = provider.hasEstimate;

    final metrics = <(IconData, String, String, String)>[
      (
        Icons.schedule_outlined,
        'Total Estimated Hours',
        hasEstimate ? formatHours(provider.totalHours) : '—',
        'across every work type',
      ),
      (
        Icons.groups_outlined,
        'Estimated Workers',
        hasEstimate ? formatCount(provider.estimatedWorkers) : '—',
        'to hit the deadline',
      ),
      (
        Icons.calendar_month_outlined,
        'Estimated Duration',
        hasEstimate ? '${formatCount(provider.estimatedDurationDays)} d' : '—',
        'working days of standard production',
      ),
      (
        Icons.verified_outlined,
        'Based On Projects',
        hasEstimate ? formatCount(provider.sampleSize) : '—',
        switch (provider.accuracyPercent) {
          _ when !hasEstimate => 'comparable past jobs',
          final accuracy? => '~${accuracy.toStringAsFixed(0)}% accuracy',
          null => 'accuracy cannot be estimated',
        },
      ),
    ];

    return Row(
      children: [
        for (final (index, metric) in metrics.indexed) ...[
          Expanded(
            child: _MetricCard(
              icon: metric.$1,
              label: metric.$2,
              value: metric.$3,
              caption: metric.$4,
              muted: !hasEstimate,
            ),
          ),
          if (index < metrics.length - 1) const SizedBox(width: AppSpacing.gap),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.muted,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final bool muted;

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
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: muted ? AppColors.textMuted : AppColors.textPrimary,
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

/// The "why" behind the numbers above - explainable recommendations, not a
/// bare figure the office has to trust blind.
class _ExplanationBanner extends StatelessWidget {
  const _ExplanationBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
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
          Expanded(child: _TableBody(provider: provider)),
        ],
      ),
    );
  }
}

class _TableBody extends StatelessWidget {
  const _TableBody({required this.provider});

  final RecommendationsProvider provider;

  @override
  Widget build(BuildContext context) {
    if (!provider.asked) {
      return _EmptyState(
        icon: Icons.insights_outlined,
        title: 'Nothing to estimate yet',
        message: 'Pick a project type, an expected tonnage and a deadline, '
            'then press Estimate.',
      );
    }

    if (provider.estimating) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.estimateError != null) {
      return _EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'The estimate could not be produced',
        message: provider.estimateError!,
      );
    }

    if (provider.noDataMessage != null) {
      return _EmptyState(
        icon: Icons.hourglass_empty,
        title: 'Not enough history yet',
        message: provider.noDataMessage!,
      );
    }

    if (!provider.hasEstimate || provider.workTypes.isEmpty) {
      return _EmptyState(
        icon: Icons.hourglass_empty,
        title: 'No estimate yet',
        message: 'The estimator has nothing to break down for this project type.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: provider.workTypes.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _WorkTypeRow(workType: provider.workTypes[index]),
    );
  }
}

class _WorkTypeRow extends StatelessWidget {
  const _WorkTypeRow({required this.workType});

  final RecommendationWorkType workType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    workType.operationTypeName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _DistributionBar(sharePercent: workType.sharePercent),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatHours(workType.estimatedHours),
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${workType.sharePercent.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({required this.sharePercent});

  final double sharePercent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: 8,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              height: 8,
              width: constraints.maxWidth * (sharePercent.clamp(0, 100) / 100),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Says plainly why the table is empty rather than dressing it up.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
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
