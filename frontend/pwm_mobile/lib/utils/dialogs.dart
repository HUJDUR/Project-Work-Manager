import 'package:flutter/material.dart';

import '../screens/widgets/app_toast.dart';

void showSavedSnackBar(BuildContext context, String message) {
  showAppToast(context, message: message);
}

void showErrorSnackBar(BuildContext context, String message) {
  showAppToast(context, message: message, type: ToastType.error);
}
