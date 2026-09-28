import 'package:flutter/foundation.dart';

import '../models/notification.dart';
import '../utils/api_client_exception.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';

enum ReceivedNotificationsStatus { idle, loading, ready, failed }

/// What the office has sent the signed-in account. Distinct from
/// [NotificationsProvider], which is the Send Notification screen's own store
/// for composing a broadcast — this one only reads and marks read.
///
/// Backs two different views of the same table:
///
///  * The bell popup ([unreadOnly] true): the newest [pageSize] unread rows.
///    [refreshUnread] re-asks for these on every screen change and on
///    `MasterScreen`'s own poll timer, so a notification sent mid-session
///    shows up without the office having to go looking for it; reading one — alone or
///    via "mark all" — keeps it on screen, struck through as read, rather
///    than dropping it. It only stops showing once this provider is
///    recreated, which happens the next time `NotificationBell` is mounted
///    after a sign-in. That is what makes a read notification "disappear
///    from the bell at the next logout" rather than the moment it is opened
///    or the screen is changed.
///  * The Notifications screen's history card ([unreadOnly] false): every row,
///    newest first, paged with "Load more" — read or not.
///
/// Scoped to the signed-in account throughout, and the API narrows a write to
/// the token's own rows besides, so the two agree even if this ever asked for
/// somebody else's.
class ReceivedNotificationsProvider extends ChangeNotifier {
  ReceivedNotificationsProvider({
    NotificationProvider? notifications,
    int? userId,
    this.unreadOnly = false,
    this.pageSize = 8,
  })  : _notifications = notifications ?? NotificationProvider(),
        _userId = userId ?? AuthProvider.user?.id;

  /// The bell's mode: only ever the newest unread rows, and read does not mean
  /// gone — see the class doc.
  final bool unreadOnly;

  /// How many rows a page holds.
  final int pageSize;

  final NotificationProvider _notifications;
  final int? _userId;

  ReceivedNotificationsStatus _status = ReceivedNotificationsStatus.idle;
  String? _errorMessage;

  List<Notification> _rows = const [];
  int _page = 1;
  int? _totalCount;
  int _unreadCount = 0;
  bool _isLoadingMore = false;
  bool _isMarking = false;

  ReceivedNotificationsStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ReceivedNotificationsStatus.loading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isMarking => _isMarking;
  List<Notification> get rows => _rows;
  int? get totalCount => _totalCount;
  int get unreadCount => _unreadCount;
  bool get isEmpty =>
      _status == ReceivedNotificationsStatus.ready && _rows.isEmpty;

  /// True while the API says there are rows past the ones already shown.
  bool get hasMore {
    final total = _totalCount;
    return total != null && _rows.length < total;
  }

  /// First page, plus the unread count the badge and the button read. In
  /// [unreadOnly] mode the page **is** the unread rows, so the count comes
  /// free with it rather than costing a second request.
  Future<void> load() async {
    _status = ReceivedNotificationsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    if (_userId == null) {
      _errorMessage = 'No account is signed in.';
      _status = ReceivedNotificationsStatus.failed;
      notifyListeners();
      return;
    }

    try {
      _page = 1;

      if (unreadOnly) {
        _rows = await _fetchPage(_page);
        _unreadCount = _totalCount ?? 0;
      } else {
        final results = await Future.wait([_fetchPage(_page), _countUnread()]);
        _rows = results[0] as List<Notification>;
        _unreadCount = results[1] as int;
      }

      _status = ReceivedNotificationsStatus.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = ReceivedNotificationsStatus.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading notifications: $error';
      _status = ReceivedNotificationsStatus.failed;
    }

    notifyListeners();
  }

  /// Bell-only: re-asks for what is unread so a notification sent since this
  /// provider last loaded shows up without waiting for the next sign-in —
  /// called whenever the desktop switches screens.
  ///
  /// A plain [load] would do that too, but it would also **drop** anything
  /// already read this session, since a fresh unread-only fetch does not come
  /// back with those rows at all. So this folds the fresh unread rows in
  /// alongside whatever is already shown and marked read, rather than
  /// replacing the list outright — the fetch is the same one [load] makes,
  /// only what happens with the answer differs. A row that was unread and
  /// is no longer in the fresh page (because it was read from elsewhere, or
  /// aged out of the newest [pageSize]) is dropped, the same as it would be
  /// on the next full [load].
  Future<void> refreshUnread() async {
    if (!unreadOnly || _userId == null) return;

    try {
      final fresh = await _fetchPage(1);
      _page = 1;

      final freshIds = fresh.map((row) => row.id).toSet();
      final stillReadFromBefore =
          _rows.where((row) => row.isRead && !freshIds.contains(row.id));

      _rows = [...fresh, ...stillReadFromBefore]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _unreadCount = _totalCount ?? 0;
      _errorMessage = null;

      if (_status != ReceivedNotificationsStatus.ready) {
        _status = ReceivedNotificationsStatus.ready;
      }
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'Something went wrong while checking for new notifications: $error';
    }

    notifyListeners();
  }

  /// The next page, appended. Quietly does nothing when there is no more or a
  /// page is already on its way, so a second click cannot double up the list.
  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final next = await _fetchPage(_page + 1);

      _page += 1;
      _rows = [..._rows, ...next];
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading more: $error';
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// One notification, marked read because it was opened. Nothing is sent for
  /// one already read, so reopening a card costs no request.
  ///
  /// The row is swapped in place rather than dropped — in [unreadOnly] mode
  /// that is what keeps it in the bell until the next sign-in.
  Future<void> markRead(Notification notification) async {
    if (notification.isRead) return;

    try {
      await _notifications.markRead(ids: [notification.id]);

      _rows = [
        for (final row in _rows) row.id == notification.id ? row.read : row,
      ];
      if (_unreadCount > 0) _unreadCount--;
      _errorMessage = null;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'The notification could not be marked as read: $error';
    }

    notifyListeners();
  }

  /// Every unread notification this account has, including — in the history
  /// card's mode — ones past the last page loaded; the API resolves the list
  /// server-side from the token rather than from what is on screen.
  ///
  /// The history card reloads afterwards, so its list and its count stay in
  /// step. The bell does not: reloading would ask the API for unread rows
  /// only and get none back, clearing it on the spot rather than at the next
  /// sign-in, so it patches [_rows] in place instead — the same bargain
  /// [markRead] makes for one row at a time.
  Future<void> markAllRead() async {
    if (_isMarking || _unreadCount == 0) return;

    _isMarking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _notifications.markRead();

      if (unreadOnly) {
        _rows = [for (final row in _rows) row.read];
        _unreadCount = 0;
      }
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'They could not be marked as read: $error';
    }

    _isMarking = false;

    if (_errorMessage != null) {
      notifyListeners();
      return;
    }

    if (unreadOnly) {
      notifyListeners();
    } else {
      await load();
    }
  }

  Future<List<Notification>> _fetchPage(int page) async {
    final result = await _notifications.get(filter: {
      'userId': _userId,
      if (unreadOnly) 'isRead': false,
      'page': page,
      'pageSize': pageSize,
      'includeTotalCount': true,
      // Newest first: a notification is read from the top down.
      'sortBy': 'CreatedAt desc',
    });

    _totalCount = result.totalCount;

    return result.items;
  }

  /// A count, not a page. `pageSize` is 1 rather than 0 because
  /// `BaseReadService` clamps a page to at least one row; the row it answers
  /// with is thrown away.
  Future<int> _countUnread() async {
    final result = await _notifications.get(filter: {
      'userId': _userId,
      'isRead': false,
      'page': 1,
      'pageSize': 1,
      'includeTotalCount': true,
    });

    return result.totalCount ?? 0;
  }
}
