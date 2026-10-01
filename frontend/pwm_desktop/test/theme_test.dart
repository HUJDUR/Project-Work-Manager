import 'dart:io';

import 'package:flutter/material.dart' as legacy;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pwm_desktop/main.dart';
import 'package:pwm_desktop/providers/auth_provider.dart';
import 'package:pwm_desktop/screens/login_screen.dart';
import 'package:pwm_desktop/utils/app_theme.dart';

Color _colourOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.color!;

/// Reads the global palette on every build, the same way a real screen would -
/// just without needing one, since the toggle only cares that *something*
/// already on screen repaints.
class _Probe extends StatelessWidget {
  const _Probe();

  static const caption = 'palette probe';

  @override
  Widget build(BuildContext context) {
    return Text(caption, style: TextStyle(color: AppColors.textSecondary));
  }
}

void main() {
  tearDown(() => AppColors.palette = AppColors.paletteFor(ThemeController.defaultMode));

  test('the app opens dark', () {
    expect(ThemeController.defaultMode, ThemeMode.dark);
    expect(ThemeController().isDark, isTrue);
    expect(AppColors.palette, AppPalette.dark);
  });

  testWidgets('a toggle repaints the whole tree, not only what is rebuilt',
      (tester) async {
    final controller = ThemeController();

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeController>.value(
        value: controller,
        child: Consumer<ThemeController>(
          builder: (context, theme, _) => MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: theme.mode,
            // Not const: a const subtree here would never rebuild on toggle, which
            // is exactly the bug this test exists to catch.
            home: Scaffold(body: _Probe()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_colourOf(tester, _Probe.caption), AppPalette.dark.textSecondary);

    controller.toggle();
    await tester.pumpAndSettle();

    // The colour is read from a global palette, so this only holds while nothing
    // between the toggle and the text blocks the rebuild.
    expect(_colourOf(tester, _Probe.caption), AppPalette.light.textSecondary);
  });

  test('no widget of this project is const-constructed', () {
    // A `const` widget instance is canonically identical across rebuilds, so
    // Flutter skips its subtree — and every colour in that subtree comes from
    // the global `AppColors` palette, which a theme toggle has just changed.
    // Const-constructing one leaves part of the window in the old theme until
    // something else forces it to rebuild. Framework widgets are fine: the ones
    // that carry a colour take it as an argument, which is checked at the call.
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) =>
            file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'))
        .toList();

    final declared = <String>{};
    for (final file in sources) {
      declared.addAll(RegExp(
        r'^class\s+([A-Za-z_][A-Za-z0-9_]*)\s+extends\s+(?:Stateless|Stateful)Widget',
        multiLine: true,
      ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!));
    }
    expect(declared, isNotEmpty, reason: 'no widget classes found to check');

    // A constructor *declaration* keeps its `const` — that is what lets the
    // analyzer's prefer_const_constructors_in_immutables stay satisfied, and it
    // costs nothing. Only the call sites have to give it up, so a `const Foo(`
    // sitting inside `class Foo` is the declaration and is skipped.
    final classAt = RegExp(r'^class\s+([A-Za-z_][A-Za-z0-9_]*)');

    final offenders = <String>[];
    for (final file in sources) {
      final lines = file.readAsStringSync().split('\n');
      var enclosing = '';

      for (var i = 0; i < lines.length; i++) {
        enclosing = classAt.firstMatch(lines[i])?.group(1) ?? enclosing;

        for (final name in declared) {
          if (name == enclosing) continue;
          if (RegExp('\\bconst\\s+$name\\s*\\(').hasMatch(lines[i])) {
            offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These widgets read the global palette but would not rebuild when '
          'it changes:\n${offenders.join('\n')}',
    );
  });

  testWidgets(
      "widgets still on Flutter's bundled Material (charts, the PDF preview) see the app theme",
      (tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: PwmDesktopApp(),
    ));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(LoginScreen));
    expect(legacy.Theme.of(context).brightness, Brightness.dark);
    expect(legacy.Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary);
  });
}
