import 'dart:async';

import 'package:material_ui/material_ui.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/notification.dart';
import 'package:pwm_desktop/models/page_result.dart';
import 'package:pwm_desktop/providers/notification_provider.dart';
import 'package:pwm_desktop/providers/received_notifications_provider.dart';
import 'package:pwm_desktop/screens/widgets/notification_list.dart';
import 'package:pwm_desktop/utils/notification_groups.dart';
import 'package:pwm_desktop/utils/sarajevo_time.dart';

/// Newest first, as the API answers; a test inserts at the front to "send" one.
class _FakeNotifications extends NotificationProvider {
  _FakeNotifications(this.rows);

  final List<Notification> rows;
  int requests = 0;

  @override
  Future<PageResult<Notification>> get({dynamic filter}) async {
    requests++;
    final query = Map<String, dynamic>.from(filter as Map);
    final hits = query['isRead'] == false ? rows.where((row) => !row.isRead).toList() : rows;
    final page = query['page'] as int;
    final size = query['pageSize'] as int;

    return PageResult<Notification>()
      ..items = hits.skip((page - 1) * size).take(size).toList()
      ..totalCount = hits.length;
  }
}

Notification _sent(int id, DateTime at, {bool isRead = false}) => Notification(
      id: id,
      userId: 1,
      title: 'Notification $id',
      message: 'Message $id',
      isRead: isRead,
      createdAt: at,
    );

void main() {
  final now = SarajevoTime.now();
  final today = DateTime(now.year, now.month, now.day, 9);
  final yesterday = today.subtract(const Duration(days: 1));
  final lastWeek = today.subtract(const Duration(days: 7));

  group('notificationDayOf', () {
    final noon = DateTime(2026, 9, 30, 12);

    test('splits by calendar day, not by the last 24 hours', () {
      expect(notificationDayOf(DateTime(2026, 9, 30, 0, 5), now: noon), NotificationDay.today);
      expect(notificationDayOf(DateTime(2026, 9, 29, 23, 55), now: noon), NotificationDay.yesterday);
      expect(notificationDayOf(DateTime(2026, 9, 29, 0, 1), now: noon), NotificationDay.yesterday);
      expect(notificationDayOf(DateTime(2026, 9, 28, 23, 59), now: noon), NotificationDay.earlier);
    });

    test('groups in section order and leaves empty sections out', () {
      final groups = groupNotificationsByDay(
        [DateTime(2026, 9, 30, 8), DateTime(2026, 9, 20), DateTime(2026, 9, 30, 7)],
        (at) => at,
        now: noon,
      );

      expect(groups.map((group) => group.$1), [NotificationDay.today, NotificationDay.earlier]);
      expect(groups.first.$2, [DateTime(2026, 9, 30, 8), DateTime(2026, 9, 30, 7)]);
    });
  });

  group('live refresh', () {
    test('a push folds the new notification in without a loading state', () async {
      final api = _FakeNotifications([_sent(2, yesterday), _sent(1, lastWeek, isRead: true)]);
      final pushes = StreamController<void>.broadcast();
      final provider = ReceivedNotificationsProvider(notifications: api, userId: 1, changes: pushes.stream);
      addTearDown(provider.dispose);

      await provider.load();
      expect(provider.unreadCount, 1);

      final states = <ReceivedNotificationsStatus>[];
      provider.addListener(() => states.add(provider.status));

      api.rows.insert(0, _sent(3, today));
      pushes.add(null);
      await pumpEventQueue();

      expect(provider.rows.map((row) => row.id), [3, 2, 1]);
      expect(provider.unreadCount, 2);
      expect(states, isNot(contains(ReceivedNotificationsStatus.loading)));
    });

    test('the bell folds in only what is unread', () async {
      final api = _FakeNotifications([_sent(2, yesterday)]);
      final pushes = StreamController<void>.broadcast();
      final bell = ReceivedNotificationsProvider(
          notifications: api, userId: 1, unreadOnly: true, pageSize: 5, changes: pushes.stream);
      addTearDown(bell.dispose);

      await bell.load();
      api.rows.insert(0, _sent(3, today));
      pushes.add(null);
      await pumpEventQueue();

      expect(bell.rows.map((row) => row.id), [3, 2]);
      expect(bell.unreadCount, 2);
    });

    test('stops listening once disposed', () async {
      final api = _FakeNotifications([_sent(1, today)]);
      final pushes = StreamController<void>.broadcast();
      final provider = ReceivedNotificationsProvider(notifications: api, userId: 1, changes: pushes.stream);

      await provider.load();
      provider.dispose();
      final before = api.requests;

      pushes.add(null);
      await pumpEventQueue();

      expect(api.requests, before);
    });
  });

  testWidgets('the list is split into Today, Yesterday and Earlier', (tester) async {
    final provider = ReceivedNotificationsProvider(
      notifications: _FakeNotifications([_sent(3, today), _sent(2, yesterday), _sent(1, lastWeek)]),
      userId: 1,
      changes: const Stream.empty(),
    );
    addTearDown(provider.dispose);
    await provider.load();

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: NotificationsList(provider: provider))));

    double top(String text) => tester.getTopLeft(find.text(text)).dy;

    expect(top('TODAY'), lessThan(top('Notification 3')));
    expect(top('YESTERDAY'), greaterThan(top('Notification 3')));
    expect(top('YESTERDAY'), lessThan(top('Notification 2')));
    expect(top('EARLIER'), greaterThan(top('Notification 2')));
    expect(top('EARLIER'), lessThan(top('Notification 1')));
  });
}
