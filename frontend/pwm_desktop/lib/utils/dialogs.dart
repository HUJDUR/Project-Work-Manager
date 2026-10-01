import 'package:material_ui/material_ui.dart';

import '../screens/widgets/app_toast.dart';
import 'app_theme.dart';

/// Asks before an action that cannot be undone. Answers false when the dialog
/// is dismissed rather than confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

/// Asks why - for a rejection, which the API refuses without a reason. Returns
/// the trimmed reason, or null when the dialog was cancelled.
Future<String?> askReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _ReasonDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
      ),
    );

/// Mirrors `StatusChangeRules.ReasonMaxLength` on the API.
const int reasonMaxLength = 500;

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  /// Shown under the field once confirming was refused, then kept in step.
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _check(String value) =>
      value.trim().isEmpty ? 'Give a reason - it is kept with the status change.' : null;

  void _confirm() {
    final error = _check(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: reasonMaxLength,
              decoration: InputDecoration(
                labelText: 'Reason',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                if (_error != null) setState(() => _error = _check(value));
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _confirm,
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

void showErrorDialog(BuildContext context, String title, String message) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void showSavedSnackBar(BuildContext context, String message) {
  showAppToast(context, message: message);
}

void showErrorSnackBar(BuildContext context, String message) {
  showAppToast(context, message: message, type: ToastType.error);
}

/// Flutter's own calendar-mode range picker sizes itself to the whole window
/// by default (`size = MediaQuery.sizeOf(context)`, zero inset padding) -
/// unlike the single-date picker, it has no built-in compact mode. This is
/// the size every date-range popup in the app opens at instead.
const _dateRangePickerSize = Size(440, 560);

/// Every date-range field in the app should open through this rather than
/// calling `showDateRangePicker` directly, so a full-screen calendar can
/// never creep back in one screen at a time. Feeding the picker a smaller
/// [MediaQuery] through its `builder` is what actually shrinks it, since
/// that size is all it reads to decide how big to draw itself.
Future<DateTimeRange?> pickDateRange(
  BuildContext context, {
  required DateTimeRange? initialDateRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDateRangePicker(
    context: context,
    initialDateRange: initialDateRange,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(size: _dateRangePickerSize),
      child: child!,
    ),
  );
}
