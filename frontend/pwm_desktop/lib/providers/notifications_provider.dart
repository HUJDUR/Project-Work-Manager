import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import 'base_provider.dart';
import 'notification_provider.dart';
import 'user_provider.dart';
import 'user_type_provider.dart';

enum NotificationsStatusState { idle, loading, ready, failed }

/// The Send Notification screen's own store. It holds who the message is going
/// to; the message itself lives in the form until it is sent.
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({
    NotificationProvider? notifications,
    BaseProvider<User>? users,
    BaseProvider<UserType>? userTypes,
  })  : _notifications = notifications ?? NotificationProvider(),
        _users = users ?? UserProvider(),
        _userTypes = userTypes ?? UserTypeProvider();

  /// Only accounts that still work can be written to, and the API says the same.
  static const String sortBy = 'Surname, Name';

  final NotificationProvider _notifications;
  final BaseProvider<User> _users;
  final BaseProvider<UserType> _userTypes;

  NotificationsStatusState _status = NotificationsStatusState.idle;
  String? _errorMessage;

  List<User> _all = const [];
  Map<int, String> _roleById = const {};

  bool _toEveryone = true;
  final Set<int> _selectedIds = {};
  String _search = '';

  NotificationsStatusState get status => _status;
  String? get errorMessage => _errorMessage;

  /// Everyone who can be written to, in the order the API sorted them.
  List<User> get allRecipients => _all;

  /// The slice the recipient list shows, narrowed by the search box.
  List<User> get recipients {
    final needle = _search.trim().toLowerCase();
    if (needle.isEmpty) return _all;

    return _all
        .where((user) =>
            user.fullName.toLowerCase().contains(needle) ||
            user.email.toLowerCase().contains(needle) ||
            (_roleById[user.userTypeId] ?? '').toLowerCase().contains(needle))
        .toList();
  }

  String roleOf(User user) => _roleById[user.userTypeId] ?? 'Unknown role';

  bool get toEveryone => _toEveryone;
  String get search => _search;

  Set<int> get selectedIds => Set.unmodifiable(_selectedIds);

  bool isSelected(int userId) => _toEveryone || _selectedIds.contains(userId);

  /// What the "3 of 12 selected" line counts. Sending to everyone counts as all
  /// of them, because that is what the API will do with an empty list.
  int get selectedCount => _toEveryone ? _all.length : _selectedIds.length;

  int get totalCount => _all.length;

  /// Nothing to send to means the Send button stays disabled.
  bool get canSend => selectedCount > 0;

  void setToEveryone(bool value) {
    _toEveryone = value;
    notifyListeners();
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  /// Ticking someone while "All workers" is set switches to picking by hand,
  /// which is what the mockup's two radios mean.
  void toggle(int userId) {
    if (_toEveryone) {
      _toEveryone = false;
      _selectedIds
        ..clear()
        ..addAll(_all.map((user) => user.id));
    }

    if (!_selectedIds.remove(userId)) _selectedIds.add(userId);
    notifyListeners();
  }

  void clearSelection() {
    _toEveryone = true;
    _selectedIds.clear();
    _search = '';
    notifyListeners();
  }

  Future<void> load() async {
    _status = NotificationsStatusState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _users.getAll(filter: {'isActive': true, 'sortBy': sortBy}),
        _userTypes.getAll(),
      ]);

      final users = results[0] as List<User>;
      final types = results[1] as List<UserType>;

      _roleById = {for (final type in types) type.id: type.type};
      _all = users;

      _status = NotificationsStatusState.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = NotificationsStatusState.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading recipients: $error';
      _status = NotificationsStatusState.failed;
    }

    notifyListeners();
  }

  /// Sends the message and answers how many people it reached. Sending to
  /// everyone leaves the ids off, so the API resolves the list rather than the
  /// client posting one it may have loaded a while ago.
  Future<int> send({required String title, required String message}) {
    return _notifications.sendNotification(
      title: title,
      message: message,
      userIds: _toEveryone ? null : _selectedIds.toList(),
    );
  }
}
