import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pwm_mobile/layouts/master_screen.dart';
import 'package:pwm_mobile/providers/auth_provider.dart';

/// A small phone — the width the six-entry bottom bar has to survive.
const _phone = Size(390, 844);

/// Options, the last tab still without a screen. The shell tests are about the
/// bar, not about what a tab holds, so they open on a [PlaceholderBody]: a real
/// screen would go looking for an API. Move this as tabs get built.
const _placeholderTab = 5;
const _otherPlaceholderTab = 4;

Future<void> _pumpShell(WidgetTester tester,
    {int initialIndex = _placeholderTab}) async {
  tester.view
    ..physicalSize = _phone
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
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
      expect(find.text(label), findsOneWidget, reason: '$label is missing');
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('the bar swaps the body rather than stacking screens',
      (tester) async {
    await _pumpShell(tester, initialIndex: _otherPlaceholderTab);
    expect(find.text('Notifications is not built yet'), findsOneWidget);

    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications is not built yet'), findsNothing);
    expect(find.text('Options is not built yet'), findsOneWidget);
    // One shell, one screen deep — nothing was pushed over it.
    expect(find.byType(MasterScreen), findsOneWidget);
  });

  testWidgets('the bell opens the notifications tab', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications is not built yet'), findsOneWidget);
  });
}
