import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/notification.dart';
import 'package:pwm_desktop/models/page_result.dart';
import 'package:pwm_desktop/providers/notification_provider.dart';
import 'package:pwm_desktop/providers/received_notifications_provider.dart';
import 'package:pwm_desktop/screens/widgets/notification_bell.dart';

/// A fake `/Notification` endpoint: `get` pages the in-memory rows the way
/// the API pages the table, and `markRead` flips `isRead` on them the way
/// `POST /Notification/MarkRead` does on the server.
class _FakeNotificationProvider extends NotificationProvider {
  _FakeNotificationProvider(this.rows);

  final List<Notification> rows;
  final List<List<int>?> markReadCalls = [];

  @override
  Future<PageResult<Notification>> get({dynamic filter}) async {
    final query = Map<String, dynamic>.from((filter as Map?) ?? const {});

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
  required String title,
  required String message,
  required bool isRead,
  DateTime? createdAt,
}) {
  return Notification(
    id: id,
    userId: 1,
    title: title,
    message: message,
    isRead: isRead,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Builds the provider the way `MasterScreen` now does — the bell no longer
/// creates its own — loads it, pumps the bell around it, and hands the
/// provider back so a test can drive it directly (a screen change, in the
/// real app, calling `refreshUnread` on it).
Future<ReceivedNotificationsProvider> _pumpBell(
  WidgetTester tester,
  NotificationProvider fake, {
  VoidCallback? onViewAll,
}) async {
  final provider = ReceivedNotificationsProvider(
    notifications: fake,
    userId: 1,
    unreadOnly: true,
    pageSize: 5,
  );
  await provider.load();

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topRight,
        child: NotificationBell(
          provider: provider,
          onViewAll: onViewAll ?? () {},
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  return provider;
}

void main() {
  testWidgets('shows the unread count as a badge on the bell', (tester) async {
    final fake = _FakeNotificationProvider([
      _notification(id: 1, title: 'Shift change', message: 'Starts at 7am.', isRead: false),
      _notification(id: 2, title: 'Safety notice', message: 'Wear ear protection.', isRead: true),
    ]);

    await _pumpBell(tester, fake);

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets(
      'the popup lists only unread notifications, newest handful, not what was already read',
      (tester) async {
    final fake = _FakeNotificationProvider([
      _notification(id: 1, title: 'Shift change', message: 'Starts at 7am.', isRead: false),
      _notification(id: 2, title: 'Safety notice', message: 'Wear ear protection.', isRead: true),
    ]);

    await _pumpBell(tester, fake);

    expect(find.text('Shift change'), findsNothing);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('1 unread'), findsOneWidget);
    expect(find.text('Shift change'), findsOneWidget);
    // Already read before the bell ever loaded, so it was never fetched.
    expect(find.text('Safety notice'), findsNothing);
  });

  testWidgets(
      'reading one in the popup keeps it on screen rather than dropping it',
      (tester) async {
    final fake = _FakeNotificationProvider([
      _notification(id: 1, title: 'Shift change', message: 'Starts at 7am.', isRead: false),
    ]);

    await _pumpBell(tester, fake);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Shift change'));
    await tester.pumpAndSettle();

    expect(fake.markReadCalls.single, [1]);
    // Read, so the unread line is gone, but the card is still right there.
    expect(find.text('All read'), findsOneWidget);
    expect(find.text('Shift change'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('mark all as read clears the badge but keeps the cards on screen',
      (tester) async {
    final fake = _FakeNotificationProvider([
      _notification(id: 1, title: 'Shift change', message: 'Starts at 7am.', isRead: false),
      _notification(id: 2, title: 'Overtime', message: 'Saturday shift.', isRead: false),
    ]);

    await _pumpBell(tester, fake);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    expect(find.text('2 unread'), findsOneWidget);

    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();

    expect(fake.markReadCalls.single, isNull);
    expect(find.text('All read'), findsOneWidget);
    // The badge on the bell itself is also gone.
    expect(find.text('2'), findsNothing);
    // But nothing vanished from the popup — that only happens at the next
    // sign-in, when a fresh bell only ever asks for what is still unread.
    expect(find.text('Shift change'), findsOneWidget);
    expect(find.text('Overtime'), findsOneWidget);
  });

  testWidgets('reopening the popup does not re-ask the API and drop what was read',
      (tester) async {
    final fake = _FakeNotificationProvider([
      _notification(id: 1, title: 'Shift change', message: 'Starts at 7am.', isRead: false),
    ]);

    await _pumpBell(tester, fake);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shift change'));
    await tester.pumpAndSettle();

    // Close and reopen within the same session.
    await tester.tapAt(const Offset(10, 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    expect(find.text('Shift change'), findsOneWidget);
  });

  testWidgets(
      'a screen change picks up a notification sent mid-session without dropping one already read',
      (tester) async {
    final fake = _FakeNotificationProvider([
      _notification(id: 1, title: 'Shift change', message: 'Starts at 7am.', isRead: false),
    ]);

    final provider = await _pumpBell(tester, fake);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shift change'));
    await tester.pumpAndSettle();

    expect(find.text('All read'), findsOneWidget);

    // A second notification arrives while this session is still open — the
    // same table a new sign-in would see, just discovered mid-session
    // instead, the way `MasterScreen` asks on every screen change.
    fake.rows.add(_notification(
      id: 2,
      title: 'Overtime',
      message: 'Saturday shift.',
      isRead: false,
    ));

    await provider.refreshUnread();
    await tester.pumpAndSettle();

    expect(find.text('1 unread'), findsOneWidget);
    expect(find.text('Overtime'), findsOneWidget);
    // Still there — a refresh must not repeat what a reopen already does not.
    expect(find.text('Shift change'), findsOneWidget);
  });

  testWidgets('"See all notifications" closes the popup and hands off to the caller',
      (tester) async {
    final fake = _FakeNotificationProvider([
      _notification(id: 1, title: 'Shift change', message: 'Starts at 7am.', isRead: false),
    ]);

    var viewAllTapped = false;
    await _pumpBell(tester, fake, onViewAll: () => viewAllTapped = true);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    await tester.tap(find.text('See all notifications'));
    await tester.pumpAndSettle();

    expect(viewAllTapped, isTrue);
    expect(find.text('Shift change'), findsNothing);
  });

  testWidgets('clicking outside the popup dismisses it', (tester) async {
    final fake = _FakeNotificationProvider([
      _notification(id: 1, title: 'Shift change', message: 'Starts at 7am.', isRead: false),
    ]);

    await _pumpBell(tester, fake);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();
    expect(find.text('Shift change'), findsOneWidget);

    await tester.tapAt(const Offset(10, 400));
    await tester.pumpAndSettle();

    expect(find.text('Shift change'), findsNothing);
  });

  testWidgets('an empty inbox says so', (tester) async {
    final fake = _FakeNotificationProvider([]);

    await _pumpBell(tester, fake);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    expect(find.text('No new notifications'), findsOneWidget);
  });
}
