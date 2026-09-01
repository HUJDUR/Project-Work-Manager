import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// The frame every details screen renders into: a back button, the title, the
/// save and delete actions, and the form itself on a card. Delete is offered
/// only when [onDelete] is given, which is what separates editing from adding.
class DetailsScaffold extends StatelessWidget {
  const DetailsScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onSave,
    this.onDelete,
    this.saving = false,
    this.errorMessage,
    this.formWidth = 720,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// Null while a save is impossible, which greys the button out.
  final VoidCallback? onSave;

  /// Null when the record does not exist yet.
  final VoidCallback? onDelete;

  final bool saving;
  final String? errorMessage;
  final double formWidth;

  @override
  Widget build(BuildContext context) {
    // Its own scaffold: the screen is pushed as a route, so it cannot borrow the
    // Material the list screen sits on.
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              title: title,
              subtitle: subtitle,
              onSave: saving ? null : onSave,
              onDelete: saving ? null : onDelete,
              saving: saving,
            ),
            const SizedBox(height: AppSpacing.gap),
            if (errorMessage != null) ...[
              _ErrorBanner(message: errorMessage!),
              const SizedBox(height: AppSpacing.gap),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: formWidth),
                    child: AppCard(child: child),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onSave,
    required this.onDelete,
    required this.saving,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (onDelete != null) ...[
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.dangerBorder),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            ),
          ),
          const SizedBox(width: 12),
        ],
        FilledButton.icon(
          onPressed: onSave,
          icon: saving
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check, size: 18),
          label: const Text('Save'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        border: Border.all(color: AppColors.dangerBorder),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
