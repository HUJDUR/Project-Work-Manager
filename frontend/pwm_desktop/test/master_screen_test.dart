import 'package:material_ui/material_ui.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pwm_desktop/layouts/master_screen.dart';
import 'package:pwm_desktop/models/notification.dart';
import 'package:pwm_desktop/models/page_result.dart';
import 'package:pwm_desktop/providers/auth_provider.dart';
import 'package:pwm_desktop/providers/notification_provider.dart';
import 'package:pwm_desktop/providers/received_notifications_provider.dart';
import 'package:pwm_desktop/utils/app_theme.dart';

/// A fake `/Notification` endpoint, the same shape `notification_bell_test.dart`
/// and `received_notifications_provider_test.dart` use.
class _FakeNotificationProvider extends NotificationProvider {
  _FakeNotificationProvider(this.rows);

  final List<Notification> rows;

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
    final toMark =
        ids ?? rows.where((row) => !row.isRead).map((row) => row.id).toList();

    var marked = 0;
    for (var i = 0; i < rows.length; i++) {
      if (toMark.contains(rows[i].id) && !rows[i].isRead) {
        rows[i] = rows[i].read;
        marked++;
      }
    }

    return marked;
  }
}

Notification _notification({required int id, required bool isRead}) {
  return Notification(
    id: id,
    userId: 1,
    title: 'Notification $id',
    message: 'Message $id',
    isRead: isRead,
    createdAt: DateTime.now(),
  );
}

Future<void> _pumpShell(
  WidgetTester tester,
  NotificationProvider fake,
) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: MaterialApp(
        home: MasterScreen(
          notificationsProviderFactory: () => ReceivedNotificationsProvider(
            notifications: fake,
            userId: 1,
            unreadOnly: true,
            pageSize: 5,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'switching sidebar destinations refreshes the bell for anything sent mid-session',
      (tester) async {
    final fake = _FakeNotificationProvider([
      _notification(id: 1, isRead: false),
    ]);

    await _pumpShell(tester, fake);

    expect(find.text('1'), findsOneWidget);

    // A second notification arrives while the window stays open on some
    // other screen — the same table a fresh sign-in would see, just found
    // out about here instead of waiting for one.
    fake.rows.add(_notification(id: 2, isRead: false));

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets(
      'a screen change does not drop a notification already read this session',
      (tester) async {
    final fake = _FakeNotificationProvider([
      _notification(id: 1, isRead: false),
    ]);

    await _pumpShell(tester, fake);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notification 1'));
    await tester.pumpAndSettle();

    // Close the popup and change screens.
    await tester.tapAt(const Offset(10, 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    // Reopen the bell: the read card is still there, not gone the moment
    // the screen changed.
    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    expect(find.text('Notification 1'), findsOneWidget);
    expect(find.text('All read'), findsOneWidget);
  });
}
