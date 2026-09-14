import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_mobile/models/models.dart';
import 'package:pwm_mobile/providers/notification_provider.dart';
import 'package:pwm_mobile/providers/notifications_provider.dart';
import 'package:pwm_mobile/screens/notifications_screen.dart';
import 'package:pwm_mobile/utils/api_client_exception.dart';

/// Answers the way the API does — narrowed by `userId` and `isRead`, paged, and
/// marking read server-side from the ids alone — so a test can see what the
/// screen asked for and what it did with the answer.
class _FakeNotifications extends NotificationProvider {
  _FakeNotifications(this.rows);

  List<Notification> rows;
  final List<Map<String, dynamic>> filters = [];

  /// One entry per `MarkRead` call: the ids it named, or null for "all of mine".
  final List<List<int>?> markCalls = [];

  @override
  Future<PageResult<Notification>> get({dynamic filter}) async {
    final map = Map<String, dynamic>.from(filter as Map);
    filters.add(map);

    final matching = _matching(map);
    final page = (map['page'] as int?) ?? 1;
    final size = (map['pageSize'] as int?) ?? matching.length;

    return PageResult<Notification>()
      ..totalCount = map['includeTotalCount'] == true ? matching.length : null
      ..items = matching.skip((page - 1) * size).take(size).toList();
  }

  /// Only what the real service filters on, so a test cannot pass by narrowing
  /// client-side something the API would have returned whole.
  List<Notification> _matching(Map<String, dynamic> filter) {
    final userId = filter['userId'] as int?;
    final isRead = filter['isRead'] as bool?;

    return rows.where((row) {
      if (userId != null && row.userId != userId) return false;
      if (isRead != null && row.isRead != isRead) return false;
      return true;
    }).toList();
  }

  @override
  Future<int> markRead({List<int>? ids}) async {
    markCalls.add(ids);

    var marked = 0;
    rows = [
      for (final row in rows)
        if (!row.isRead && (ids == null || ids.contains(row.id)))
          (() {
            marked++;
            return row.read;
          })()
        else
          row,
    ];

    return marked;
  }
}

class _FailingNotifications extends NotificationProvider {
  @override
  Future<PageResult<Notification>> get({dynamic filter}) async =>
      throw ApiClientException('The API is unreachable.');
}

/// Fails only the write, so the list stays on screen behind the complaint.
class _UnwritableNotifications extends _FakeNotifications {
  _UnwritableNotifications(super.rows);

  @override
  Future<int> markRead({List<int>? ids}) async =>
      throw ApiClientException('They could not be marked as read.');
}

final _now = DateTime(2026, 9, 14, 12);

Notification _notification({
  required int id,
  bool isRead = false,
  int userId = 20,
  String title = 'Shift change',
  String message = 'Next week the early shift starts at 06:00.',
  int hoursAgo = 3,
}) =>
    Notification(
      id: id,
      userId: userId,
      title: title,
      message: message,
      isRead: isRead,
      createdAt: _now.subtract(Duration(hours: hoursAgo)),
    );

/// Twelve for this worker — four of them unread — plus one belonging to somebody
/// else, which is here precisely so a test can show it never reaches the list.
List<Notification> _rows() => [
      for (var i = 1; i <= 12; i++)
        _notification(id: i, isRead: i > 4, hoursAgo: i),
      _notification(id: 99, userId: 7, title: 'Not yours'),
    ];

({NotificationsProvider provider, _FakeNotifications api}) _build({
  _FakeNotifications? api,
  int? userId = 20,
}) {
  final fake = api ?? _FakeNotifications(_rows());

  return (
    provider: NotificationsProvider(notifications: fake, userId: userId),
    api: fake,
  );
}

void main() {
  group('the list', () {
    test('asks the API for one page of this worker, newest first', () async {
      final fixture = _build();
      await fixture.provider.load();

      expect(fixture.provider.status, NotificationsStatus.ready);
      expect(fixture.provider.rows.length, NotificationsProvider.pageSize);
      // Twelve are this worker's; the thirteenth belongs to somebody else.
      expect(fixture.provider.totalCount, 12);
      expect(
        fixture.provider.rows.every((row) => row.userId == 20),
        isTrue,
        reason: 'another account\'s notification reached the list',
      );

      final page = fixture.api.filters.first;
      expect(page['userId'], 20);
      expect(page['page'], 1);
      expect(page['pageSize'], NotificationsProvider.pageSize);
      expect(page['includeTotalCount'], true);
      expect(page['sortBy'], 'CreatedAt desc');
      expect(page.containsKey('isRead'), isFalse, reason: 'All, not Unread');
    });

    test('counts the unread ones in the table, not on the page', () async {
      final fixture = _build();
      await fixture.provider.load();

      // Four unread across twelve rows, and only eight rows were loaded.
      expect(fixture.provider.unreadCount, 4);

      final count = fixture.api.filters.last;
      expect(count['isRead'], false);
      expect(count['includeTotalCount'], true);
      expect(count['pageSize'], 1, reason: 'a count, not a page of rows');
    });

    test('the unread filter goes to the API rather than being sifted here',
        () async {
      final fixture = _build();
      await fixture.provider.load();
      await fixture.provider.applyFilter(NotificationsFilter.unread);

      expect(fixture.provider.rows.length, 4);
      expect(fixture.provider.rows.every((row) => !row.isRead), isTrue);

      final page = fixture.api.filters.firstWhere(
        (filter) => filter['page'] == 1 && filter['pageSize'] != 1,
        orElse: () => {},
      );
      expect(fixture.api.filters.last['isRead'], false);
      expect(page, isNotEmpty);
    });

    test('load more appends the next page rather than replacing it', () async {
      final fixture = _build();
      await fixture.provider.load();

      expect(fixture.provider.hasMore, isTrue);
      await fixture.provider.loadMore();

      expect(fixture.provider.rows.length, 12);
      expect(fixture.provider.rows.first.id, 1, reason: 'page one is still there');
      expect(fixture.provider.hasMore, isFalse);
    });

    test('load more does nothing once everything is shown', () async {
      final fixture = _build();
      await fixture.provider.load();
      await fixture.provider.loadMore();

      final calls = fixture.api.filters.length;
      await fixture.provider.loadMore();

      expect(fixture.api.filters.length, calls);
    });

    test('nothing is asked for when no account is signed in', () async {
      final fixture = _build(userId: null);
      await fixture.provider.load();

      expect(fixture.provider.status, NotificationsStatus.failed);
      expect(fixture.provider.errorMessage, 'No account is signed in.');
      expect(fixture.api.filters, isEmpty);
    });

    test('a dead API leaves the message it gave', () async {
      final provider = NotificationsProvider(
        notifications: _FailingNotifications(),
        userId: 20,
      );
      await provider.load();

      expect(provider.status, NotificationsStatus.failed);
      expect(provider.errorMessage, 'The API is unreachable.');
    });
  });

  group('marking read', () {
    test('opening one sends its id alone and flips it in place', () async {
      final fixture = _build();
      await fixture.provider.load();

      final first = fixture.provider.rows.first;
      expect(first.isRead, isFalse);

      await fixture.provider.markRead(first);

      expect(fixture.api.markCalls.single, [first.id]);
      expect(fixture.provider.rows.first.isRead, isTrue);
      expect(fixture.provider.rows.first.id, first.id,
          reason: 'the row stays where it is rather than vanishing');
      expect(fixture.provider.unreadCount, 3);
    });

    test('one already read costs no request', () async {
      final fixture = _build();
      await fixture.provider.load();

      final read = fixture.provider.rows.firstWhere((row) => row.isRead);
      await fixture.provider.markRead(read);

      expect(fixture.api.markCalls, isEmpty);
      expect(fixture.provider.unreadCount, 4);
    });

    test('mark all names no ids, so the API resolves the list', () async {
      final fixture = _build();
      await fixture.provider.load();

      await fixture.provider.markAllRead();

      expect(fixture.api.markCalls.single, isNull);
      expect(fixture.provider.unreadCount, 0);
      // Including the four that were never loaded onto the page.
      expect(fixture.api.rows.where((row) => !row.isRead), isEmpty);
    });

    test('mark all reloads the page, so Unread empties', () async {
      final fixture = _build();
      await fixture.provider.load();
      await fixture.provider.applyFilter(NotificationsFilter.unread);

      expect(fixture.provider.rows, isNotEmpty);
      await fixture.provider.markAllRead();

      expect(fixture.provider.rows, isEmpty);
      expect(fixture.provider.isEmpty, isTrue);
    });

    test('mark all does nothing when there is nothing unread', () async {
      final fixture = _build(
        api: _FakeNotifications([
          for (var i = 1; i <= 3; i++) _notification(id: i, isRead: true),
        ]),
      );
      await fixture.provider.load();

      await fixture.provider.markAllRead();

      expect(fixture.api.markCalls, isEmpty);
    });

    test('a refused write keeps the list and says so', () async {
      final fixture = (
        provider: NotificationsProvider(
          notifications: _UnwritableNotifications(_rows()),
          userId: 20,
        ),
      );
      await fixture.provider.load();

      await fixture.provider.markAllRead();

      expect(fixture.provider.rows, isNotEmpty);
      expect(fixture.provider.unreadCount, 4, reason: 'nothing actually changed');
      expect(
        fixture.provider.errorMessage,
        'They could not be marked as read.',
      );
    });
  });

  group('the screen', () {
    Future<_FakeNotifications> pump(
      WidgetTester tester, {
      _FakeNotifications? api,
    }) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fake = api ?? _FakeNotifications(_rows());

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotificationsScreen(
            providerFactory: () =>
                NotificationsProvider(notifications: fake, userId: 20),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      return fake;
    }

    testWidgets('says how many are unread and offers the one button',
        (tester) async {
      await pump(tester);

      expect(find.text('4 unread'), findsOneWidget);
      expect(find.text('Mark all as read'), findsOneWidget);
      expect(find.text('8 of 12 notifications'), findsOneWidget);
    });

    testWidgets('the button clears the count and then says so', (tester) async {
      final api = await pump(tester);

      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();

      expect(api.markCalls.single, isNull);
      expect(find.text('4 unread'), findsNothing);
      expect(find.text('All read'), findsOneWidget);
    });

    testWidgets('the button does nothing when everything is read',
        (tester) async {
      final api = await pump(
        tester,
        api: _FakeNotifications([
          for (var i = 1; i <= 3; i++) _notification(id: i, isRead: true),
        ]),
      );

      expect(find.text('All read'), findsOneWidget);
      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();

      expect(api.markCalls, isEmpty);
    });

    testWidgets('tapping a card opens it and reads it', (tester) async {
      final api = await pump(tester);

      await tester.tap(find.text('Shift change').first);
      await tester.pumpAndSettle();

      expect(api.markCalls.single, [1]);
      expect(find.text('3 unread'), findsOneWidget);
    });

    testWidgets('a stamp with no zone is read as UTC, not as local time',
        (tester) async {
      // What the API actually sends: `DateTime.UtcNow` serialised without a
      // trailing Z. Parsed as local it would read hours old the moment it was
      // sent, by however far this machine sits from UTC.
      final sentNow = DateTime.parse(
        DateTime.now().toUtc().toIso8601String().replaceFirst('Z', ''),
      );

      await pump(
        tester,
        api: _FakeNotifications([
          Notification(
            id: 1,
            userId: 20,
            title: 'Shift change',
            message: 'Next week the early shift starts at 06:00.',
            isRead: false,
            createdAt: sentNow,
          ),
        ]),
      );

      expect(find.text('just now'), findsOneWidget);
    });

    testWidgets('a failure offers a way to try again', (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NotificationsScreen(
            providerFactory: () => NotificationsProvider(
              notifications: _FailingNotifications(),
              userId: 20,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Notifications could not be loaded'), findsOneWidget);
      expect(find.text('The API is unreachable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
