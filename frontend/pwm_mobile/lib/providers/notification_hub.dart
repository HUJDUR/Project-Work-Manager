import 'dart:async';

import 'package:signalr_netcore/iretry_policy.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'auth_provider.dart';
import 'base_provider.dart';

/// Live notifications: the API's SignalR hub tells this account's apps the moment
/// a notification is written for it, and every notifications list reloads itself
/// - no refresh by hand.
///
/// The hub sends only that signal; the notifications are still read through the
/// API as before. One connection per signed-in session: `MasterScreen` opens it
/// and closes it again when the session ends.
abstract final class NotificationHub {
  static const _path = 'hubs/notifications';
  static const _changedMessage = 'notificationsChanged';
  static const _retryDelay = Duration(seconds: 10);

  static final _changes = StreamController<void>.broadcast();

  /// Fires when the API says this account's notifications changed, and after
  /// every reconnect - whatever arrived while the line was down is picked up then.
  static Stream<void> get changes => _changes.stream;

  static HubConnection? _connection;
  static Timer? _retry;
  static bool _wanted = false;

  /// Opens the connection for the signed-in account. Does nothing when nobody
  /// is signed in or it is already open; a server that cannot be reached yet is
  /// retried until [disconnect].
  static Future<void> connect() async {
    if (_wanted || !AuthProvider.isSignedIn) return;
    _wanted = true;

    final connection = HubConnectionBuilder()
        .withUrl(
          '${BaseProvider.baseUrl}$_path',
          // Asked on every (re)connect, so a refreshed token is the one sent.
          options: HttpConnectionOptions(
            accessTokenFactory: () async => AuthProvider.accesstoken ?? '',
          ),
        )
        .withAutomaticReconnect(reconnectPolicy: _KeepTrying())
        .build();

    connection.on(_changedMessage, (_) => _changes.add(null));
    connection.onreconnected(({connectionId}) => _changes.add(null));
    connection.onclose(({error}) => _scheduleStart());

    _connection = connection;
    await _start();
  }

  /// Closes the connection - on sign-out, or when the session expires.
  static Future<void> disconnect() async {
    _wanted = false;
    _retry?.cancel();
    _retry = null;

    final connection = _connection;
    _connection = null;

    try {
      await connection?.stop();
    } catch (_) {
      // Already down - there is nothing left to close.
    }
  }

  static Future<void> _start() async {
    final connection = _connection;
    if (!_wanted || connection == null) return;

    try {
      await connection.start();
    } catch (_) {
      _scheduleStart();
    }
  }

  static void _scheduleStart() {
    if (!_wanted) return;

    _retry?.cancel();
    _retry = Timer(_retryDelay, _start);
  }
}

/// SignalR's default gives up after four tries; a shop-floor phone losing Wi-Fi
/// for a minute should not lose live notifications for the rest of the shift.
class _KeepTrying implements IRetryPolicy {
  @override
  int? nextRetryDelayInMilliseconds(RetryContext retryContext) =>
      retryContext.previousRetryCount == 0 ? 0 : NotificationHub._retryDelay.inMilliseconds;
}
