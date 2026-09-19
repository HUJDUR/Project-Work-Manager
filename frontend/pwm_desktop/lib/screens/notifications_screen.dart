import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/notifications_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import 'widgets/form_fields.dart';

/// Writes one message to the shop floor, laid out as in
/// `docs/mockups/desktop/Notifications.png`.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, this.providerFactory});

  /// Lets a test swap in a provider backed by fake data.
  final NotificationsProvider Function()? providerFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => (providerFactory?.call() ?? NotificationsProvider())..load(),
      child: Consumer<NotificationsProvider>(
        builder: (context, provider, _) {
          return switch (provider.status) {
            NotificationsStatusState.failed => _ErrorState(
                message: provider.errorMessage ?? 'Recipients could not be loaded.',
                onRetry: provider.load,
              ),
            NotificationsStatusState.ready => _Body(provider: provider),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final NotificationsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(),
          const SizedBox(height: AppSpacing.gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _MessageCard(provider: provider)),
                const SizedBox(width: AppSpacing.gap),
                Expanded(flex: 2, child: _RecipientsCard(provider: provider)),
              ],
            ),
          ),
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
        Text(
          'Send Notification',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 2),
        Text(
          'Create and send a notification to your workers',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _MessageCard extends StatefulWidget {
  const _MessageCard({required this.provider});

  final NotificationsProvider provider;

  @override
  State<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<_MessageCard> {
  final _formKey = GlobalKey<FormBuilderState>();

  bool _sending = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Message details',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.gap),
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: AppSpacing.gap),
            ],
            FormBuilder(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormBuilderTextField(
                    name: 'title',
                    decoration: appInputDecoration(
                      'Title',
                      hintText: 'What this is about',
                    ),
                    validator: FormBuilderValidators.required(
                      errorText: 'A notification needs a title.',
                    ),
                  ),
                  const SizedBox(height: formFieldGap),
                  FormBuilderTextField(
                    name: 'message',
                    minLines: 6,
                    maxLines: 10,
                    decoration: appInputDecoration(
                      'Message',
                      hintText: 'What the workers need to know',
                    ),
                    validator: FormBuilderValidators.required(
                      errorText: 'A notification needs a message.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Tooltip(
                  message: provider.canSend
                      ? 'Send Notification'
                      : 'Pick at least one recipient first.',
                  child: FilledButton.icon(
                    onPressed: _sending || !provider.canSend ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined, size: 18),
                    label: const Text('Send Notification'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _sending ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  ),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                Text(
                  provider.toEveryone
                      ? 'Going to all ${provider.totalCount}'
                      : 'Going to ${provider.selectedCount}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;

    final values = _formKey.currentState!.value;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final sent = await widget.provider.send(
        title: (values['title'] as String).trim(),
        message: (values['message'] as String).trim(),
      );

      if (!mounted) return;
      showSavedSnackBar(
        context,
        'Notification sent to $sent ${sent == 1 ? 'person' : 'people'}',
      );
      _reset();
    } catch (error) {
      setState(() {
        _error = error is ApiClientException
            ? error.message
            : 'The notification could not be sent: $error';
      });
    }

    if (mounted) setState(() => _sending = false);
  }

  void _cancel() {
    _reset();
    widget.provider.clearSelection();
  }

  void _reset() {
    _formKey.currentState?.reset();
    setState(() => _error = null);
  }
}

/// Everyone, or the people ticked below. The two radios and the list are one
/// control: ticking somebody switches the radio to Selected workers.
class _RecipientsCard extends StatefulWidget {
  const _RecipientsCard({required this.provider});

  final NotificationsProvider provider;

  @override
  State<_RecipientsCard> createState() => _RecipientsCardState();
}

class _RecipientsCardState extends State<_RecipientsCard> {
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Recipients',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _AudienceOption(
                  label: 'All workers',
                  selected: provider.toEveryone,
                  onTap: () => provider.setToEveryone(true),
                ),
                _AudienceOption(
                  label: 'Selected workers',
                  selected: !provider.toEveryone,
                  onTap: () => provider.setToEveryone(false),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: provider.setSearch,
                  decoration: const InputDecoration(
                    hintText: 'Search workers',
                    prefixIcon: Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: provider.recipients.isEmpty
                ? Center(
                    child: Text(
                      'Nobody matches that search.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: provider.recipients.length,
                    itemBuilder: (context, index) {
                      final user = provider.recipients[index];
                      return _RecipientTile(
                        user: user,
                        role: provider.roleOf(user),
                        checked: provider.isSelected(user.id),
                        onChanged: () => provider.toggle(user.id),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(
              '${provider.selectedCount} of ${provider.totalCount} selected',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceOption extends StatelessWidget {
  const _AudienceOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}

class _RecipientTile extends StatelessWidget {
  const _RecipientTile({
    required this.user,
    required this.role,
    required this.checked,
    required this.onChanged,
  });

  final User user;
  final String role;
  final bool checked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accentSoft,
              child: Text(
                user.initials,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    role,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(value: checked, onChanged: (_) => onChanged()),
          ],
        ),
      ),
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
          Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: AppColors.danger),
            ),
          ),
        ],
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
              'Recipients could not be loaded',
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
