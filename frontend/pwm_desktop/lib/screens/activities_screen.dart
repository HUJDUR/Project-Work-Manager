import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/activities_provider.dart';
import '../utils/app_theme.dart';
import 'widgets/activities_table.dart';

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
