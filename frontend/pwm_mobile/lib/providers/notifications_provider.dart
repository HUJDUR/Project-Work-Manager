import 'package:flutter/foundation.dart';

import '../models/notification.dart';
import '../utils/api_client_exception.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';

enum NotificationsStatus { idle, loading, ready, failed }

/// Which of the worker's notifications the list is showing. It goes to the API
/// as `isRead` rather than being sifted in Dart — the table grows by one row per
/// person per message, so it is not something to read whole.
enum NotificationsFilter {
  all('All'),
  unread('Unread');

  const NotificationsFilter(this.label);

  final String label;
}

/// The Notifications tab: what the office has sent this worker.
///
/// Scoped to the signed-in account throughout. `userId` narrows the list, and
/// the API narrows the write to the token's own rows besides, so the two agree
/// even if this ever asked for somebody else's.
///
/// **Paging goes to the API**, the way the Projects tab does it: a page is
/// appended by "Load more" rather than replacing what is on screen, and a
/// filter change starts again at page one.
///
/// The unread count is its own count-only request rather than something counted
/// off the page, because "3 unread" has to mean three in the table and not three
/// among the eight rows that happen to be loaded — the trick the desktop's
/// project counters use.
///
/// This one injects [NotificationProvider] itself rather than a
/// `BaseProvider<Notification>`: marking read is a custom endpoint that lives on
/// the subclass, so there is nothing generic to hand in. A test subclasses it.
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({
    NotificationProvider? notifications,
    int? userId,
  })  : _notifications = notifications ?? NotificationProvider(),
        _userId = userId ?? AuthProvider.user?.id;

  /// A page a thumb can scroll through, the same as the Projects tab.
  static const int pageSize = 8;

  final NotificationProvider _notifications;
  final int? _userId;

  NotificationsStatus _status = NotificationsStatus.idle;
  String? _errorMessage;

  List<Notification> _rows = const [];
  NotificationsFilter _filter = NotificationsFilter.all;
  int _page = 1;
  int? _totalCount;
  int _unreadCount = 0;
  bool _isLoadingMore = false;
  bool _isMarking = false;

  NotificationsStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == NotificationsStatus.loading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isMarking => _isMarking;
  List<Notification> get rows => _rows;
  NotificationsFilter get filter => _filter;
  int? get totalCount => _totalCount;
  int get unreadCount => _unreadCount;
  bool get isEmpty => _status == NotificationsStatus.ready && _rows.isEmpty;

  /// True while the API says there are rows past the ones already shown.
  bool get hasMore {
    final total = _totalCount;
    return total != null && _rows.length < total;
  }

  Future<void> applyFilter(NotificationsFilter filter) async {
    if (filter == _filter) return;

    _filter = filter;
    await load();
  }

  /// First page, plus the unread count the header and the button read.
  Future<void> load() async {
    _status = NotificationsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    if (_userId == null) {
      _errorMessage = 'No account is signed in.';
      _status = NotificationsStatus.failed;
      notifyListeners();
      return;
    }

    try {
      _page = 1;
      final results = await Future.wait([_fetchPage(_page), _countUnread()]);
      _rows = results[0] as List<Notification>;
      _unreadCount = results[1] as int;

      _status = NotificationsStatus.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = NotificationsStatus.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading notifications: $error';
      _status = NotificationsStatus.failed;
    }

    notifyListeners();
  }

  /// The next page, appended. Quietly does nothing when there is no more or a
  /// page is already on its way, so a second tap cannot double up the list.
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
  /// The row is swapped in place rather than dropped, even under the Unread
  /// filter: a card vanishing from under the thumb that just tapped it reads as
  /// a mis-tap. It leaves on the next load, which is when the filter is asked
  /// again anyway.
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

  /// Every unread notification this worker has, **including the ones past the
  /// last page loaded** — that is what the button says, and the API resolves the
  /// list server-side from the token rather than from what is on screen.
  ///
  /// It reloads afterwards rather than patching the rows: under the Unread
  /// filter there is nothing left to show, so the page has to be asked again.
  Future<void> markAllRead() async {
    if (_isMarking || _unreadCount == 0) return;

    _isMarking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _notifications.markRead();
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

    await load();
  }

  Future<List<Notification>> _fetchPage(int page) async {
    final result = await _notifications.get(filter: {
      'userId': _userId,
      if (_filter == NotificationsFilter.unread) 'isRead': false,
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
