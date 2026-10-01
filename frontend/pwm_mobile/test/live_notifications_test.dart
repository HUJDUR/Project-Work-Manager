import 'dart:async';

import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_mobile/models/notification.dart';
import 'package:pwm_mobile/models/page_result.dart';
import 'package:pwm_mobile/providers/notification_provider.dart';
import 'package:pwm_mobile/providers/notifications_provider.dart';
import 'package:pwm_mobile/screens/notifications_screen.dart';
import 'package:pwm_mobile/utils/notification_groups.dart';
import 'package:pwm_mobile/utils/sarajevo_time.dart';

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

  test('sections split by calendar day, not by the last 24 hours', () {
    final noon = DateTime(2026, 9, 30, 12);

    expect(notificationDayOf(DateTime(2026, 9, 30, 0, 5), now: noon), NotificationDay.today);
    expect(notificationDayOf(DateTime(2026, 9, 29, 23, 55), now: noon), NotificationDay.yesterday);
    expect(notificationDayOf(DateTime(2026, 9, 28, 23, 59), now: noon), NotificationDay.earlier);
  });

  test('a push folds the new notification in without a loading state', () async {
    final api = _FakeNotifications([_sent(2, yesterday), _sent(1, lastWeek, isRead: true)]);
    final pushes = StreamController<void>.broadcast();
    final provider = NotificationsProvider(notifications: api, userId: 1, changes: pushes.stream);
    addTearDown(provider.dispose);

    await provider.load();
    expect(provider.unreadCount, 1);

    final states = <NotificationsStatus>[];
    provider.addListener(() => states.add(provider.status));

    api.rows.insert(0, _sent(3, today));
    pushes.add(null);
    await pumpEventQueue();

    expect(provider.rows.map((row) => row.id), [3, 2, 1]);
    expect(provider.unreadCount, 2);
    expect(states, isNot(contains(NotificationsStatus.loading)));
  });

  test('stops listening once disposed', () async {
    final api = _FakeNotifications([_sent(1, today)]);
    final pushes = StreamController<void>.broadcast();
    final provider = NotificationsProvider(notifications: api, userId: 1, changes: pushes.stream);

    await provider.load();
    provider.dispose();
    final before = api.requests;

    pushes.add(null);
    await pumpEventQueue();

    expect(api.requests, before);
  });

  testWidgets('the tab is split into Today, Yesterday and Earlier', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NotificationsScreen(
          providerFactory: () => NotificationsProvider(
            notifications: _FakeNotifications([_sent(3, today), _sent(2, yesterday), _sent(1, lastWeek)]),
            userId: 1,
            changes: const Stream.empty(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    double top(String text) => tester.getTopLeft(find.text(text)).dy;

    expect(top('TODAY'), lessThan(top('Notification 3')));
    expect(top('YESTERDAY'), greaterThan(top('Notification 3')));
    expect(top('YESTERDAY'), lessThan(top('Notification 2')));
    expect(top('EARLIER'), greaterThan(top('Notification 2')));
    expect(top('EARLIER'), lessThan(top('Notification 1')));
  });
}
