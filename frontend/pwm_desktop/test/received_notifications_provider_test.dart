import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/notification.dart';
import 'package:pwm_desktop/models/page_result.dart';
import 'package:pwm_desktop/providers/notification_provider.dart';
import 'package:pwm_desktop/providers/received_notifications_provider.dart';

class _FakeNotificationProvider extends NotificationProvider {
  _FakeNotificationProvider(this.rows);

  final List<Notification> rows;
  final List<Map<String, dynamic>> requests = [];
  final List<List<int>?> markReadCalls = [];

  @override
  Future<PageResult<Notification>> get({dynamic filter}) async {
    final query = Map<String, dynamic>.from((filter as Map?) ?? const {});
    requests.add(query);

    var hits = rows;
    if (query['isRead'] != null) {
      hits = hits.where((row) => row.isRead == query['isRead']).toList();
    }

    final page = query['page'] as int? ?? 1;
    final pageSize = query['pageSize'] as int? ?? hits.length;
    final start = (page - 1) * pageSize;
    final items = start >= hits.length
        ? <Notification>[]
        : hits.sublist(start, (start + pageSize).clamp(0, hits.length));

    return PageResult<Notification>()
      ..items = items
      ..totalCount =
          (query['includeTotalCount'] as bool? ?? false) ? hits.length : null;
  }

  @override
  Future<int> markRead({List<int>? ids}) async {
    markReadCalls.add(ids);
    final toMark =
        ids ?? rows.where((row) => !row.isRead).map((row) => row.id).toList();

    for (var i = 0; i < rows.length; i++) {
      if (toMark.contains(rows[i].id)) rows[i] = rows[i].read;
    }

    return toMark.length;
  }
}

Notification _notification({
  required int id,
  required bool isRead,
  DateTime? createdAt,
}) {
  return Notification(
    id: id,
    userId: 1,
    title: 'Notification $id',
    message: 'Message $id',
    isRead: isRead,
    createdAt: createdAt ?? DateTime.now(),
  );
}

void main() {
  group('unreadOnly mode (the bell)', () {
    test('caps the page at pageSize even with more unread than that', () async {
      final fake = _FakeNotificationProvider([
        for (var i = 1; i <= 9; i++) _notification(id: i, isRead: false),
      ]);
      final provider = ReceivedNotificationsProvider(
        notifications: fake,
        userId: 1,
        unreadOnly: true,
        pageSize: 5,
      );

      await provider.load();

      expect(provider.rows, hasLength(5));
      // The badge counts every unread row, not only the ones shown.
      expect(provider.unreadCount, 9);
    });

    test('never fetches a row that was already read', () async {
      final fake = _FakeNotificationProvider([
        _notification(id: 1, isRead: false),
        _notification(id: 2, isRead: true),
      ]);
      final provider = ReceivedNotificationsProvider(
        notifications: fake, userId: 1, unreadOnly: true, pageSize: 5,
      );

      await provider.load();

      expect(provider.rows.map((row) => row.id), [1]);
      expect(fake.requests.single['isRead'], isFalse);
    });

    test('costs one request, not the two the history card needs', () async {
      final fake = _FakeNotificationProvider([_notification(id: 1, isRead: false)]);
      final provider = ReceivedNotificationsProvider(
        notifications: fake, userId: 1, unreadOnly: true, pageSize: 5,
      );

      await provider.load();

      expect(fake.requests, hasLength(1));
    });

    test('marking all read patches the rows in place instead of reloading',
        () async {
      final fake = _FakeNotificationProvider([
        _notification(id: 1, isRead: false),
        _notification(id: 2, isRead: false),
      ]);
      final provider = ReceivedNotificationsProvider(
        notifications: fake, userId: 1, unreadOnly: true, pageSize: 5,
      );
      await provider.load();
      final requestsBeforeMarking = fake.requests.length;

      await provider.markAllRead();

      // No second load(): the row count of API calls does not grow past the
      // one markRead call.
      expect(fake.requests, hasLength(requestsBeforeMarking));
      expect(provider.unreadCount, 0);
      // Still there, just flipped to read, rather than gone.
      expect(provider.rows, hasLength(2));
      expect(provider.rows.every((row) => row.isRead), isTrue);
    });
  });

  group('full history mode (the Notifications screen)', () {
    test('shows read and unread rows alike', () async {
      final fake = _FakeNotificationProvider([
        _notification(id: 1, isRead: false),
        _notification(id: 2, isRead: true),
      ]);
      final provider =
          ReceivedNotificationsProvider(notifications: fake, userId: 1);

      await provider.load();

      expect(provider.rows.map((row) => row.id), [1, 2]);
      expect(provider.unreadCount, 1);
    });

    test('marking all read reloads, so the list and the count stay in step',
        () async {
      final fake = _FakeNotificationProvider([
        _notification(id: 1, isRead: false),
        _notification(id: 2, isRead: false),
      ]);
      final provider =
          ReceivedNotificationsProvider(notifications: fake, userId: 1);
      await provider.load();
      final requestsBeforeMarking = fake.requests.length;

      await provider.markAllRead();

      // A page request plus an unread-count request, same as `load()`.
      expect(fake.requests.length, requestsBeforeMarking + 2);
      expect(provider.unreadCount, 0);
      expect(provider.rows.every((row) => row.isRead), isTrue);
    });

    test('pages through more than one page with loadMore', () async {
      final fake = _FakeNotificationProvider([
        for (var i = 1; i <= 5; i++) _notification(id: i, isRead: false),
      ]);
      final provider = ReceivedNotificationsProvider(
        notifications: fake, userId: 1, pageSize: 2,
      );

      await provider.load();
      expect(provider.rows, hasLength(2));
      expect(provider.hasMore, isTrue);

      await provider.loadMore();
      expect(provider.rows, hasLength(4));

      await provider.loadMore();
      expect(provider.rows, hasLength(5));
      expect(provider.hasMore, isFalse);
    });
  });
}
