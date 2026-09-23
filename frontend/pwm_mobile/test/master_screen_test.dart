import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pwm_mobile/layouts/master_screen.dart';
import 'package:pwm_mobile/models/models.dart';
import 'package:pwm_mobile/providers/auth_provider.dart';
import 'package:pwm_mobile/providers/notification_provider.dart';
import 'package:pwm_mobile/providers/notifications_provider.dart';
import 'package:pwm_mobile/utils/app_theme.dart';

/// A small phone — the width the six-entry bottom bar has to survive.
const _phone = Size(390, 844);

/// Every tab is built now, so the shell tests open on the two that reach no
/// API: Options reads only the signed-in account, and Notifications stops at
/// "No account is signed in." because these tests sign nobody in.
const _optionsTab = 5;
const _notificationsTab = 4;

/// Answers `get`/`markRead` from in-memory rows, the same shape
/// `notifications_test.dart` uses for the tab itself — here it backs the
/// bottom bar's own badge provider instead.
class _FakeNotifications extends NotificationProvider {
  _FakeNotifications(this.rows);

  List<Notification> rows;

  @override
  Future<PageResult<Notification>> get({dynamic filter}) async {
    final map = Map<String, dynamic>.from(filter as Map);
    final userId = map['userId'] as int?;
    final isRead = map['isRead'] as bool?;

    final matching = rows.where((row) {
      if (userId != null && row.userId != userId) return false;
      if (isRead != null && row.isRead != isRead) return false;
      return true;
    }).toList();

    final page = (map['page'] as int?) ?? 1;
    final size = (map['pageSize'] as int?) ?? matching.length;

    return PageResult<Notification>()
      ..totalCount = map['includeTotalCount'] == true ? matching.length : null
      ..items = matching.skip((page - 1) * size).take(size).toList();
  }

  @override
  Future<int> markRead({List<int>? ids}) async {
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
  WidgetTester tester, {
  int initialIndex = _optionsTab,
  List<Notification> unreadNotifications = const [],
}) async {
  tester.view
    ..physicalSize = _phone
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: MaterialApp(
        home: MasterScreen(
          initialIndex: initialIndex,
          notificationsProviderFactory: () => NotificationsProvider(
            notifications: _FakeNotifications(unreadNotifications),
            userId: 1,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the top bar names the product in full on a phone', (tester) async {
    await _pumpShell(tester);

    // The name shrinks rather than ellipsising, so it is still findable whole
    // beside the avatar.
    expect(find.text('PWM - Project Work Manager'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every tab of the bottom bar is named in full on a phone',
      (tester) async {
    await _pumpShell(tester);

    for (final label in const [
      'Dashboard',
      'Clock In',
      'My Hours',
      'Projects',
      'Notifications',
      'Options',
    ]) {
      // Scoped to the bar's own FittedBox rather than the whole tree: a tab's
      // screen heads itself with its tab's name, so `find.text('Options')`
      // matches the heading too once that tab is open.
      expect(
        find.descendant(
          of: find.byType(FittedBox),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: '$label is missing from the bar',
      );
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('the bar swaps the body rather than stacking screens',
      (tester) async {
    await _pumpShell(tester, initialIndex: _notificationsTab);
    // The subtitle, not the heading: "Notifications" is also a tab label.
    expect(find.text('Messages from the office'), findsOneWidget);

    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();

    expect(find.text('Messages from the office'), findsNothing);
    // The subtitle again: "Options" is also a tab label.
    expect(find.text('Your account and this app'), findsOneWidget);
    // One shell, one screen deep — nothing was pushed over it.
    expect(find.byType(MasterScreen), findsOneWidget);
  });

  testWidgets(
      'the bottom bar badges Notifications with the unread count, the way the desktop bell does',
      (tester) async {
    await _pumpShell(tester, unreadNotifications: [
      _notification(id: 1, isRead: false),
      _notification(id: 2, isRead: false),
    ]);

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('nothing unread draws no badge', (tester) async {
    await _pumpShell(tester, unreadNotifications: [
      _notification(id: 1, isRead: true),
    ]);

    expect(find.text('1'), findsNothing);
  });

  testWidgets(
      'every tab switch re-asks for the unread count, so reading something '
      'on the Notifications tab clears the badge on the way out',
      (tester) async {
    final fake = _FakeNotifications([
      _notification(id: 1, isRead: false),
      _notification(id: 2, isRead: false),
    ]);

    tester.view
      ..physicalSize = _phone
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: MaterialApp(
          home: MasterScreen(
            initialIndex: _notificationsTab,
            notificationsProviderFactory: () =>
                NotificationsProvider(notifications: fake, userId: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);

    // Something reads both — the tab's own screen doing it is one way, but
    // this stands for any of them, since the badge provider only finds out
    // once asked again.
    await fake.markRead();

    // Still showing while the Notifications tab is the one on screen — a
    // badge for a tab is not something that tab needs to see about itself.
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsNothing);
  });

  testWidgets(
      'switching between two tabs neither of which is Notifications still '
      'picks up something sent meanwhile',
      (tester) async {
    final fake = _FakeNotifications([
      _notification(id: 1, isRead: false),
    ]);

    tester.view
      ..physicalSize = _phone
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: MaterialApp(
          home: MasterScreen(
            initialIndex: _optionsTab,
            notificationsProviderFactory: () =>
                NotificationsProvider(notifications: fake, userId: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);

    // A second one arrives while nobody is anywhere near the Notifications
    // tab.
    fake.rows.add(_notification(id: 2, isRead: false));

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
  });
}
