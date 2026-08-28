import 'package:flutter/material.dart';

/// Nothing sets [accesstoken] until the API grows a sign-in endpoint, so the
/// header `createHeaders` sends is empty for now.
class AuthProvider with ChangeNotifier {
  static String? accesstoken;

  static bool get isSignedIn => (accesstoken ?? '').isNotEmpty;

  static void signOut() => accesstoken = null;
}
