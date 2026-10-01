import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/transports_provider.dart';
import '../utils/api_client_exception.dart';
import '../utils/app_roles.dart';
import '../utils/app_theme.dart';
import '../utils/dialogs.dart';
import '../utils/formatters.dart';
import '../utils/truck_load_status_rules.dart';
import 'transport_details_screen.dart' show TransportDetailsScreen, unloadColors;
import 'widgets/form_fields.dart';
import 'widgets/transports_table.dart' show TruckLoadStatusChip;

/// The read-only overview a transport row opens to, the same split Project
/// Details already has: this reads, "Edit Transport" is the only way into
/// [TransportDetailsScreen], which this leaves untouched.
class TransportOverviewScreen extends StatefulWidget {
  const TransportOverviewScreen({super.key, required this.provider, required this.row});

  /// Owns the write calls the edit form needs and the lookups it prefills
  /// its dropdowns from.
  final TransportsProvider provider;

  final TransportRow row;

  @override
  State<TransportOverviewScreen> createState() => _TransportOverviewScreenState();
}

class _TransportOverviewScreenState extends State<TransportOverviewScreen> {
  /// Kept in state rather than read straight off [widget.row]: editing or a
  /// status change can change it, and there is no reason to leave the page
  /// to see that.
  late TransportRow _row;

  List<TransportLine> _lines = const [];
  List<TruckLoadStatusChangeEntry> _statusHistory = const [];
  bool _loading = true;
  bool _changingStatus = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _row = widget.row;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        widget.provider.linesOf(_row.id),
        widget.provider.statusHistory(_row.id),
      ]);

      if (!mounted) return;
      setState(() {
        _lines = results[0] as List<TransportLine>;
        _statusHistory = results[1] as List<TruckLoadStatusChangeEntry>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(error, 'The transport could not be loaded');
        _loading = false;
      });
    }
  }

  Future<void> _editTransport() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => TransportDetailsScreen(provider: widget.provider, row: _row),
      ),
    );
    if (result != 'reload' || !mounted) return;

    await _refresh();
  }

  Future<void> _refresh() async {
    await widget.provider.refresh();
    if (!mounted) return;

    final fresh = await widget.provider.fetchRow(_row.id);
    if (!mounted) return;
    setState(() => _row = fresh);

    await _load();
  }

  Future<void> _changeStatus(String targetStatus, int targetStatusId) async {
    double? price;
    String? reason;

    if (targetStatus == TruckLoadStatusRules.finished) {
      price = await _askInvoiceAmount();
      if (price == null) return;
    } else if (targetStatus == TruckLoadStatusRules.rejected) {
      // A rejection is final and has to say why - the API refuses one without.
      reason = await askReasonDialog(
        context,
        title: 'Reject transport',
        message: 'Reject ${_row.transportNo}? This is final - only its notes can be changed '
            'after that.',
        confirmLabel: 'Reject',
      );
      if (reason == null || !mounted) return;
    } else {
      final confirmed = await confirmDialog(
        context,
        title: 'Change status',
        message: 'Move ${_row.transportNo} from "${_row.statusName}" to "$targetStatus"?',
        confirmLabel: 'Move to $targetStatus',
        destructive: false,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() {
      _changingStatus = true;
      _error = null;
    });

    try {
      await widget.provider.changeStatus(_row.id, targetStatusId, price: price, reason: reason);
      if (!mounted) return;
      showSavedSnackBar(context, 'Status changed to $targetStatus');
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, _messageFor(error, 'The status could not be changed'));
    }

    if (mounted) setState(() => _changingStatus = false);
  }

  /// The popup "Finished" always opens - the invoice amount in EUR is what
  /// the API needs before it will accept that jump, and after it nothing but
  /// Notes ever changes on this load again.
  Future<double?> _askInvoiceAmount() {
    final controller = TextEditingController();

    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish transport'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: appInputDecoration('Invoice amount', suffixText: 'EUR'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.replaceAll(',', '.'));
              if (amount == null || amount <= 0) return;
              Navigator.of(context).pop(amount);
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(onEdit: _editTransport),
            const SizedBox(height: AppSpacing.gap),
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: AppSpacing.gap),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoCard(row: _row),
                    const SizedBox(height: AppSpacing.gap),
                    _StatusPanel(
                      row: _row,
                      statusTypes: widget.provider.statusTypes,
                      statusHistory: _statusHistory,
                      changing: _changingStatus,
                      onChangeStatus: _changeStatus,
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    _CargoPanel(lines: _lines, loading: _loading),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _messageFor(Object error, String fallback) =>
      error is ApiClientException ? error.message : '$fallback: $error';
}

class _Header extends StatelessWidget {
  const _Header({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transport Details',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                'Transport  ›  Transport Details',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit Transport'),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.row});

  final TransportRow row;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FieldGroup(children: [
                _Field(label: 'Transport No.', text: row.transportNo),
                _Field(label: 'Carrier', text: row.carrierName),
                _Field(label: 'Status', child: TruckLoadStatusChip(status: row.statusName)),
              ]),
            ),
            _columnDivider(),
            Expanded(
              child: _FieldGroup(children: [
                _Field(label: 'Load date', text: formatFullDate(row.loadDate)),
                _Field(label: 'Driver', text: row.driverFullName),
                _Field(label: 'Registration', text: row.vehicleRegistration),
              ]),
            ),
            _columnDivider(),
            Expanded(
              child: _FieldGroup(children: [
                _Field(label: 'Empty weight', text: '${formatCount(row.emptyWeight)} kg'),
                _Field(label: 'Full weight', text: '${formatCount(row.fullWeight)} kg'),
                _Field(label: 'Net weight', text: '${formatCount(row.netWeight)} kg'),
              ]),
            ),
            _columnDivider(),
            Expanded(
              child: _FieldGroup(children: [
                _Field(
                  label: 'Invoice amount',
                  text: row.price == null ? 'Not set' : '${formatCount(row.price!)} EUR',
                ),
                _Field(label: 'Note', text: row.note ?? 'No note'),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _columnDivider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: VerticalDivider(width: 1, color: AppColors.border),
      );
}

/// The transport's life cycle: the current status, the buttons that move it
/// on (only the jumps `TruckLoadStatusRules.allowedNext` lists, and only for
/// Admin/Project manager - everyone else just reads this panel), and the
/// audit trail of every move it has ever made.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.row,
    required this.statusTypes,
    required this.statusHistory,
    required this.changing,
    required this.onChangeStatus,
  });

  final TransportRow row;
  final List<TruckLoadStatusType> statusTypes;
  final List<TruckLoadStatusChangeEntry> statusHistory;
  final bool changing;

  /// The target status's name and id - the id is what the API call needs,
  /// the name is what the confirmation dialog and the snackbar say.
  final void Function(String status, int statusId) onChangeStatus;

  static String _labelFor(String targetStatus) => switch (targetStatus) {
        TruckLoadStatusRules.delivered => 'Mark delivered',
        TruckLoadStatusRules.finished => 'Finish transport',
        TruckLoadStatusRules.rejected => 'Reject',
        _ => targetStatus,
      };

  static IconData _iconFor(String targetStatus) => switch (targetStatus) {
        TruckLoadStatusRules.delivered => Icons.local_shipping_outlined,
        TruckLoadStatusRules.finished => Icons.paid_outlined,
        TruckLoadStatusRules.rejected => Icons.cancel_outlined,
        _ => Icons.arrow_forward,
      };

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().currentRole;
    final canChangeStatus = role == AppRoles.admin || role == AppRoles.projectManager;

    final statusIdByName = {for (final status in statusTypes) status.name: status.id};
    final nextStatuses = TruckLoadStatusRules.allowedNext(row.statusName);

    // Not `Panel`: that widget wraps its child in an `Expanded`, which needs
    // a bounded-height ancestor - this card sits straight in the page's
    // `SingleChildScrollView` and sizes to its content instead, history and all.
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            canChangeStatus
                ? 'Move this transport through its life cycle'
                : 'Only an administrator or project manager can change this',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              TruckLoadStatusChip(status: row.statusName),
              const SizedBox(width: 16),
              if (canChangeStatus && nextStatuses.isNotEmpty)
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final target in nextStatuses)
                        if (statusIdByName[target] case final targetId?)
                          OutlinedButton.icon(
                            onPressed:
                                changing ? null : () => onChangeStatus(target, targetId),
                            icon: Icon(_iconFor(target), size: 16),
                            label: Text(_labelFor(target)),
                          ),
                    ],
                  ),
                )
              else if (canChangeStatus)
                Expanded(
                  child: Text(
                    '"${row.statusName}" is final - nothing about this transport '
                    'changes from here${row.statusName == TruckLoadStatusRules.rejected ? ' but its notes' : ''}.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
          if (statusHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Text(
              'History',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            for (final change in statusHistory) _StatusHistoryRow(change: change),
          ],
        ],
      ),
    );
  }
}

class _StatusHistoryRow extends StatelessWidget {
  const _StatusHistoryRow({required this.change});

  final TruckLoadStatusChangeEntry change;

  @override
  Widget build(BuildContext context) {
    final description = change.fromStatusName == null
        ? 'Raised as "${change.toStatusName}"'
        : 'Moved from "${change.fromStatusName}" to "${change.toStatusName}"';

    final reason = change.reason;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$description by ${change.changedByName}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${formatFullDate(change.changedAt)} '
                '${formatTime(change.changedAt)}',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          if (reason != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Reason: $reason',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// What is loaded onto the truck - read-only here; cargo is only ever added,
/// changed or removed from the edit form, and only while still Ordered.
class _CargoPanel extends StatelessWidget {
  const _CargoPanel({required this.lines, required this.loading});

  final List<TransportLine> lines;
  final bool loading;

  double get _totalNeto => lines.fold(0, (total, line) => total + line.netoWeight);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cargo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            'Which projects are on the truck, and in what order they come off',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (lines.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Nothing loaded yet.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else ...[
            for (final line in lines) ...[
              _CargoLineRow(line: line),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${lines.length} ${lines.length == 1 ? 'project' : 'projects'} · '
                '${formatTonnes(_totalNeto)} net',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CargoLineRow extends StatelessWidget {
  const _CargoLineRow({required this.line});

  final TransportLine line;

  @override
  Widget build(BuildContext context) {
    final color = unloadColors[line.unloadColor] ?? AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(
              '${line.unloadPriority}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.projectName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Bruto ${formatCount(line.brutoWeight)} kg · '
                  'Neto ${formatCount(line.netoWeight)} kg'
                  '${line.unloadColor.isEmpty ? '' : ' · ${line.unloadColor}'}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final child in children) ...[
          child,
          if (child != children.last) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, this.text, this.child})
      : assert(text != null || child != null, 'Give a Field either text or a child.');

  final String label;
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        if (child case final child?)
          IntrinsicWidth(child: child)
        else
          Text(text!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
          Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 13, color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
