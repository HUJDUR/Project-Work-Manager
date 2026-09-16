import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pwm_mobile/layouts/master_screen.dart';
import 'package:pwm_mobile/providers/auth_provider.dart';
import 'package:pwm_mobile/utils/app_theme.dart';

/// A small phone — the width the six-entry bottom bar has to survive.
const _phone = Size(390, 844);

/// Every tab is built now, so the shell tests open on the two that reach no
/// API: Options reads only the signed-in account, and Notifications stops at
/// "No account is signed in." because these tests sign nobody in.
const _optionsTab = 5;
const _notificationsTab = 4;

Future<void> _pumpShell(WidgetTester tester,
    {int initialIndex = _optionsTab}) async {
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
      child: MaterialApp(home: MasterScreen(initialIndex: initialIndex)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the top bar names the product in full on a phone', (tester) async {
    await _pumpShell(tester);

    // Both the name and the bell have to fit beside the avatar; the name
    // shrinks rather than ellipsising, so it is still findable whole.
    expect(find.text('PWM - Project Work Manager'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
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

  testWidgets('the bell opens the notifications tab', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Messages from the office'), findsOneWidget);
  });
}
