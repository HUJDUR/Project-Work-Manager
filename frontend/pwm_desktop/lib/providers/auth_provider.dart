import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../models/login_result.dart';
import '../models/user.dart';
import '../utils/api_client_exception.dart';
import 'base_provider.dart';

/// The signed-in session. The token fields are static because
/// [BaseProvider.createHeaders] reads them with no BuildContext to hand;
/// the app builds exactly one instance, so the two views never disagree.
class AuthProvider with ChangeNotifier {
  static const _loginEndpoint = 'Access/Login';
  static const _refreshEndpoint = 'Access/LoginWithRefreshToken';
  static const _logoutEndpoint = 'Access/Logout';
  static const _requestPasswordResetEndpoint = 'Access/RequestPasswordReset';

  static String? accesstoken;
  static String? refreshtoken;
  static User? user;
  static String role = '';

  static bool get isSignedIn => (accesstoken ?? '').isNotEmpty;

  /// What the sign-in screen says after [expireSession] sent the user there.
  static const sessionExpiredMessage = 'Your session has expired. Please sign in again.';

  /// How [expireSession] gets back to the sign-in screen. Set once by
  /// `main.dart`, which owns the navigator; a provider does not import screens.
  static VoidCallback? onSessionExpired;

  /// The access token was refused and the refresh token could not replace it,
  /// so the session is over - drop it and go back to sign-in rather than leave
  /// the screen showing an error it cannot recover from. Screens load several
  /// things at once, so several requests can land here together: only the
  /// first, while there is still a session to end, navigates.
  static void expireSession() {
    if (!isSignedIn) return;

    accesstoken = null;
    refreshtoken = null;
    user = null;
    role = '';

    onSessionExpired?.call();
  }

  User? get currentUser => user;
  String get currentRole => role;

  /// After the account settings screen writes, so the top bar's chip shows the
  /// new name without signing in again.
  void updateCurrentUser(User updated) {
    user = updated;
    notifyListeners();
  }

  bool _isBusy = false;

  bool get isBusy => _isBusy;

  /// [emailOrUsername] is matched against the account's e-mail or its name+surname
  /// username. Throws [ApiClientException] with the API's own wording when refused.
  Future<void> login(String emailOrUsername, String password) async {
    _isBusy = true;
    notifyListeners();

    try {
      _apply(await _requestTokens(_loginEndpoint, {
        'emailOrUsername': emailOrUsername.trim(),
        'password': password,
      }));
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Drops the session locally even if telling the API about it fails.
  Future<void> signOut() async {
    final token = refreshtoken;

    if (token != null && token.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('${BaseProvider.baseUrl}$_logoutEndpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${accesstoken ?? ''}',
          },
          body: jsonEncode({'refreshToken': token}),
        );
      } catch (_) {
        // Signing out of a dead API still signs the user out of the app
      }
    }

    accesstoken = null;
    refreshtoken = null;
    user = null;
    role = '';

    notifyListeners();
  }

  /// "Reset password" on the sign-in screen, for someone who cannot sign in to
  /// do anything else. This does not reset a password itself - there is no
  /// e-mail/SMS delivery in this app to hand a new one back through - it only
  /// tells the API to notify the office, which resets it by hand. Never
  /// throws for an [emailOrUsername] that belongs to nobody: the API answers
  /// the same way either way, on purpose, so this cannot be used to find out
  /// which usernames exist.
  Future<void> requestPasswordReset(String emailOrUsername) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}$_requestPasswordResetEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'emailOrUsername': emailOrUsername.trim()}),
    );

    if (response.statusCode > 299) {
      throw ApiClientException(
        ApiErrorParser.messageFromBody(response.body) ??
            'The request could not be sent. Please try again.',
      );
    }
  }

  /// Swaps the refresh token for a new access token. Returns false when the
  /// session is gone for good, which is [BaseProvider]'s cue to surface the 401.
  static Future<bool> tryRefresh() async {
    final token = refreshtoken;

    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      _apply(await _requestTokens(_refreshEndpoint, {'refreshToken': token}));
      return true;
    } catch (_) {
      return false;
    }
  }

  static void _apply(LoginResult result) {
    accesstoken = result.accesstoken;
    refreshtoken = result.refreshtoken;
    user = result.user;
    role = result.role;
  }

  /// Sign-in cannot go through [BaseProvider]: it is what produces the token
  /// that provider's headers carry, and a 401 here must not retry itself.
  static Future<LoginResult> _requestTokens(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode > 299) {
      throw ApiClientException(
        ApiErrorParser.messageFromBody(response.body) ??
            'Sign in failed. Please try again.',
      );
    }

    return LoginResult.fromJson(jsonDecode(response.body));
  }
}
