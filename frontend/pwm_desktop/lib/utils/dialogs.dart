import 'package:flutter/material.dart';

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
