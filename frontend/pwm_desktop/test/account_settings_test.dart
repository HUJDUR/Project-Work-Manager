import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/auth_provider.dart';
import 'package:pwm_desktop/providers/user_provider.dart';
import 'package:pwm_desktop/screens/account_settings_screen.dart';
import 'package:pwm_desktop/utils/api_client_exception.dart';
import 'package:pwm_desktop/utils/app_theme.dart';
import 'package:pwm_desktop/utils/password_rules.dart';

/// `PUT /User/Me`. Nothing else on the provider is reached from this screen.
class _FakeUserProvider extends UserProvider {
  final List<Map<String, dynamic>> saved = [];

  /// Set to make the next save fail the way the API would.
  Object? failure;

  @override
  Future<User> updateProfile({
    required String name,
    required String surname,
    required String email,
    String? phoneNumber,
    String? picture,
    String? currentPassword,
    String? newPassword,
  }) async {
    saved.add({
      'name': name,
      'surname': surname,
      'email': email,
      'phoneNumber': phoneNumber,
      'picture': picture,
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    if (failure case final error?) throw error;

    return User(
      id: 1,
      name: name,
      surname: surname,
      email: email,
      userTypeId: 1,
      isActive: true,
      phoneNumber: phoneNumber,
      picture: picture,
    );
  }
}

const _signedIn = User(
  id: 1,
  name: 'Nadir',
  surname: 'Hujdur',
  email: 'admin@pwm.ba',
  userTypeId: 1,
  isActive: true,
  phoneNumber: '+387 61 000 000',
);

late _FakeUserProvider _users;

Widget _screen() {
  _users = _FakeUserProvider();

  return ChangeNotifierProvider(
    create: (_) => AuthProvider(),
    child: MaterialApp(
      home: AccountSettingsScreen(userProvider: _users),
    ),
  );
}

Finder _field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label);

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_screen());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // The session is static, the way BaseProvider.createHeaders needs it.
    AuthProvider.user = _signedIn;
    AuthProvider.role = 'Administrator';
  });

  tearDown(() {
    AuthProvider.user = null;
    AuthProvider.role = '';
  });

  group('PasswordRules', () {
    test('wants eight characters with a mix of cases, a number and a special '
        'character', () {
      expect(PasswordRules.validate('Sh0rt!'), 'At least 8 characters.');
      expect(PasswordRules.validate('lowercase1!'), 'Needs an upper-case letter.');
      expect(PasswordRules.validate('UPPERCASE1!'), 'Needs a lower-case letter.');
      expect(PasswordRules.validate('NoDigitsHere!'), 'Needs a number.');
      expect(PasswordRules.validate('Fabrika22'), 'Needs a special character.');
      expect(PasswordRules.validate(''), 'A password is required.');
      expect(PasswordRules.validate(null), 'A password is required.');

      expect(PasswordRules.validate('Fabrika22!'), isNull);
    });

    test('lets an untouched field through when editing', () {
      // Blank means "keep the one you have", which is not a broken password.
      expect(PasswordRules.validateOptional(''), isNull);
      expect(PasswordRules.validateOptional(null), isNull);
      expect(PasswordRules.validateOptional('weak'), 'At least 8 characters.');
    });

    test('checks the confirmation against what was typed', () {
      expect(PasswordRules.confirm('Fabrika22', 'Fabrika22'), isNull);
      expect(PasswordRules.confirm('Fabrika23', 'Fabrika22'),
          'The two passwords do not match.');
      expect(PasswordRules.confirm('', 'Fabrika22'), 'Type the password again.');

      // Nothing to confirm when no password is being set.
      expect(PasswordRules.confirm('', ''), isNull);
    });
  });

  group('ThemeController', () {
    tearDown(() =>
        AppColors.palette = AppColors.paletteFor(ThemeController.defaultMode));

    test('swaps the palette before it notifies', () {
      final controller = ThemeController();
      var paletteWhenNotified = AppColors.palette;
      controller.addListener(() => paletteWhenNotified = AppColors.palette);

      // The app opens dark.
      expect(controller.isDark, isTrue);
      expect(AppColors.canvas, AppPalette.dark.canvas);

      controller.toggle();

      expect(controller.isDark, isFalse);
      expect(controller.mode, ThemeMode.light);
      // The screens read AppColors during the rebuild the notification starts,
      // so the swap has to have happened by then.
      expect(paletteWhenNotified, AppPalette.light);
      expect(AppColors.canvas, AppPalette.light.canvas);

      controller.toggle();
      expect(AppColors.canvas, AppPalette.dark.canvas);
    });

    test('builds a chip that reads on whichever ground it lands on', () {
      const delivered = Color(0xFF107A4D);

      AppColors.palette = AppPalette.light;
      final (lightBackground, lightForeground) = AppColors.chip(delivered);
      expect(lightForeground, delivered);
      expect(lightBackground.a, closeTo(AppPalette.light.chipTint, 0.01));

      AppColors.palette = AppPalette.dark;
      final (_, darkForeground) = AppColors.chip(delivered);
      // Lifted towards white, or it would disappear into a dark card.
      expect(darkForeground.r, greaterThan(delivered.r));
      expect(darkForeground.g, greaterThan(delivered.g));
    });
  });

  group('AccountSettingsScreen', () {
    testWidgets('opens on the signed-in account', (tester) async {
      await _open(tester);

      expect(find.text('Account settings'), findsOneWidget);
      expect(find.text('admin@pwm.ba · Administrator'), findsOneWidget);

      expect(tester.widget<TextField>(_field('First name')).controller?.text,
          'Nadir');
      expect(tester.widget<TextField>(_field('Surname')).controller?.text,
          'Hujdur');

      // The role is shown but cannot be edited from here.
      expect(find.text('Role: '), findsOneWidget);
      expect(
        find.text('Only an administrator can change this, on the Workers screen.'),
        findsOneWidget,
      );
    });

    testWidgets('saves the details without touching the password', (tester) async {
      await _open(tester);

      await tester.enterText(_field('First name'), 'Nadira');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      // Not pumpAndSettle: the toast's own progress line keeps a frame
      // scheduled for its full four seconds, which pumpAndSettle would run
      // straight through, dismissing it before it could be asserted on here.
      await tester.pump();

      final body = _users.saved.single;
      expect(body['name'], 'Nadira');
      expect(body['email'], 'admin@pwm.ba');
      // Untouched, so the API keeps the password it has.
      expect(body['newPassword'], isNull);
      expect(body['currentPassword'], isNull);

      expect(find.text('Account updated'), findsOneWidget);
      // The cached session follows, so the top bar shows the new name.
      expect(AuthProvider.user?.name, 'Nadira');
    });

    testWidgets('refuses a new password that breaks the rules', (tester) async {
      await _open(tester);

      await tester.enterText(_field('New password'), 'weak');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('At least 8 characters.'), findsOneWidget);
      expect(_users.saved, isEmpty);
    });

    testWidgets('refuses a confirmation that does not match', (tester) async {
      await _open(tester);

      await tester.enterText(_field('New password'), 'Fabrika22!');
      await tester.enterText(_field('Confirm new password'), 'Fabrika23!');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('The two passwords do not match.'), findsOneWidget);
      expect(_users.saved, isEmpty);
    });

    testWidgets('asks for the current password before changing it',
        (tester) async {
      await _open(tester);

      await tester.enterText(_field('New password'), 'Fabrika22!');
      await tester.enterText(_field('Confirm new password'), 'Fabrika22!');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Type your current password to change it.'), findsOneWidget);
      expect(_users.saved, isEmpty);

      await tester.enterText(_field('Current password'), 'test');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final body = _users.saved.single;
      expect(body['currentPassword'], 'test');
      expect(body['newPassword'], 'Fabrika22!');
    });

    testWidgets('shows the API wording when the save is refused', (tester) async {
      await _open(tester);

      _users.failure =
          ApiClientException('Another account already uses that e-mail address.');

      await tester.enterText(_field('E-mail'), 'taken@pwm.ba');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Another account already uses that e-mail address.'),
          findsOneWidget);
    });
  });
}
