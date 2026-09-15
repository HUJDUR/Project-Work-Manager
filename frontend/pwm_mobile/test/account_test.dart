import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pwm_mobile/layouts/master_screen.dart';
import 'package:pwm_mobile/models/user.dart';
import 'package:pwm_mobile/providers/auth_provider.dart';
import 'package:pwm_mobile/providers/user_provider.dart';
import 'package:pwm_mobile/screens/account_settings_screen.dart';
import 'package:pwm_mobile/screens/login_screen.dart';
import 'package:pwm_mobile/screens/options_screen.dart';
import 'package:pwm_mobile/utils/api_client_exception.dart';

const _phone = Size(390, 844);

/// Records what `PUT /User/Me` was asked to write, so a test can see that the
/// fields this screen does not offer went back unchanged.
class _FakeUsers extends UserProvider {
  _FakeUsers({this.failure});

  final String? failure;
  final List<Map<String, Object?>> writes = [];

  @override
  Future<User> updateProfile({
    required String name,
    required String surname,
    required String email,
    String? phoneNumber,
    String? jobTitle,
    String? currentPassword,
    String? newPassword,
  }) async {
    writes.add({
      'name': name,
      'surname': surname,
      'email': email,
      'phoneNumber': phoneNumber,
      'jobTitle': jobTitle,
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });

    if (failure != null) throw ApiClientException(failure!);

    return _user(phoneNumber: phoneNumber);
  }
}

User _user({String? phoneNumber = '+387 61 234 567'}) => User(
      id: 20,
      name: 'Faruk',
      surname: 'Tufekcic',
      email: 'faruk.tufekcic@pwm.ba',
      userTypeId: 5,
      isActive: true,
      phoneNumber: phoneNumber,
      jobTitle: 'Painter',
    );

/// The session is static, so every test has to put it back.
void _signIn({User? user}) {
  AuthProvider.accesstoken = 'token';
  AuthProvider.refreshtoken = 'refresh';
  AuthProvider.user = user ?? _user();
  AuthProvider.role = 'Production worker';
}

void _signOut() {
  AuthProvider.accesstoken = null;
  AuthProvider.refreshtoken = null;
  AuthProvider.user = null;
  AuthProvider.role = '';
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view
    ..physicalSize = _phone
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view first. The form is longer than a 390x844 phone
/// and it lives in a `ListView`, so a widget below the fold is not merely off
/// screen — it has not been built, and `tap` cannot find it.
///
/// The `ListView` is named rather than left to `scrollUntilVisible`'s default,
/// which is `find.byType(Scrollable)` and matches every `TextField` as well:
/// each one carries a `Scrollable` of its own, so the default resolves to
/// several and dies as "Bad state: Too many elements".
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(ListView),
    const Offset(0, -120),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _saveChanges(WidgetTester tester) async {
  await _reveal(tester, find.text('Save changes'));
  await tester.tap(find.text('Save changes'));
  await tester.pumpAndSettle();
}

/// Types into one of the password fields, scrolling to it first.
Future<void> _typePassword(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.widgetWithText(TextField, label);
  await _reveal(tester, field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(_signOut);

  group('account settings', () {
    testWidgets('shows the account and offers only the phone number',
        (tester) async {
      _signIn();
      await _pump(tester, AccountSettingsScreen(userProvider: _FakeUsers()));

      expect(find.text('Faruk Tufekcic'), findsOneWidget);
      expect(find.text('Painter'), findsOneWidget);
      expect(find.text('Production worker'), findsWidgets);

      // Name, surname, e-mail, job title and role are facts, not fields — the
      // one editable text field besides the three password ones is the phone.
      final editable = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((field) => !field.obscureText)
          .toList();
      expect(editable.length, 1);
      expect(editable.single.controller?.text, '+387 61 234 567');
    });

    testWidgets('sends the untouched fields back exactly as they came',
        (tester) async {
      _signIn();
      final users = _FakeUsers();
      await _pump(tester, AccountSettingsScreen(userProvider: users));

      await tester.enterText(
        find.byType(TextField).first,
        '  +387 62 999 111  ',
      );
      await _saveChanges(tester);

      expect(users.writes.single, {
        'name': 'Faruk',
        'surname': 'Tufekcic',
        'email': 'faruk.tufekcic@pwm.ba',
        'phoneNumber': '+387 62 999 111',
        'jobTitle': 'Painter',
        // Nothing was typed into the password fields.
        'currentPassword': null,
        'newPassword': null,
      });
    });

    testWidgets('an emptied phone number is sent as null, not as ""',
        (tester) async {
      _signIn();
      final users = _FakeUsers();
      await _pump(tester, AccountSettingsScreen(userProvider: users));

      await tester.enterText(find.byType(TextField).first, '');
      await _saveChanges(tester);

      expect(users.writes.single['phoneNumber'], isNull);
    });

    testWidgets('a password that breaks the rules is refused before the API',
        (tester) async {
      _signIn();
      final users = _FakeUsers();
      await _pump(tester, AccountSettingsScreen(userProvider: users));

      await _typePassword(tester, 'New password', 'short');
      await _saveChanges(tester);

      expect(users.writes, isEmpty, reason: 'nothing should have been sent');
      expect(find.text('At least 8 characters.'), findsOneWidget);
    });

    testWidgets('a new password needs the current one', (tester) async {
      _signIn();
      final users = _FakeUsers();
      await _pump(tester, AccountSettingsScreen(userProvider: users));

      await _typePassword(tester, 'New password', 'Welder2026');
      await _typePassword(tester, 'Confirm new password', 'Welder2026');
      await _saveChanges(tester);

      expect(users.writes, isEmpty);
      expect(
        find.text('Type your current password to change it.'),
        findsOneWidget,
      );
    });

    testWidgets('a complete password change is sent with both halves',
        (tester) async {
      _signIn();
      final users = _FakeUsers();
      await _pump(tester, AccountSettingsScreen(userProvider: users));

      await _typePassword(tester, 'Current password', 'test');
      await _typePassword(tester, 'New password', 'Welder2026');
      await _typePassword(tester, 'Confirm new password', 'Welder2026');
      await _saveChanges(tester);

      expect(users.writes.single['currentPassword'], 'test');
      expect(users.writes.single['newPassword'], 'Welder2026');
    });

    testWidgets('a refused save keeps the API\'s own wording', (tester) async {
      _signIn();
      await _pump(
        tester,
        AccountSettingsScreen(
          userProvider: _FakeUsers(failure: 'That e-mail is already in use.'),
        ),
      );

      await _saveChanges(tester);

      expect(find.text('That e-mail is already in use.'), findsOneWidget);
    });

    testWidgets('says so rather than showing an empty form when signed out',
        (tester) async {
      await _pump(tester, AccountSettingsScreen(userProvider: _FakeUsers()));

      expect(find.text('Nobody is signed in'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('the account menu', () {
    testWidgets('the avatar opens it and names who is signed in',
        (tester) async {
      _signIn();
      await _pump(tester, MasterScreen(initialIndex: 5));

      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();

      expect(find.text('Faruk Tufekcic'), findsOneWidget);
      expect(find.text('Account settings'), findsWidgets);
      expect(find.text('Sign out'), findsWidgets);
    });

    testWidgets('account settings opens over the shell', (tester) async {
      _signIn();
      await _pump(tester, MasterScreen(initialIndex: 5));

      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account settings').last);
      await tester.pumpAndSettle();

      expect(find.byType(AccountSettingsScreen), findsOneWidget);
      // The root navigator, so the bottom bar is covered rather than left under.
      expect(find.text('Your account and this app'), findsNothing);
    });

    testWidgets('signing out ends the session and clears the stack',
        (tester) async {
      _signIn();
      await _pump(tester, MasterScreen(initialIndex: 5));

      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out').last);
      await tester.pumpAndSettle();

      expect(AuthProvider.isSignedIn, isFalse);
      expect(AuthProvider.user, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MasterScreen), findsNothing);
    });
  });

  group('the options tab', () {
    testWidgets('offers the same two things as the menu', (tester) async {
      _signIn();
      await _pump(tester, OptionsScreen(userProvider: _FakeUsers()));

      expect(find.text('Account settings'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Signed in as Faruk Tufekcic'), findsOneWidget);
    });

    testWidgets('its account settings row opens the same screen',
        (tester) async {
      _signIn();
      await _pump(tester, MasterScreen(initialIndex: 5));

      await tester.tap(find.text('Account settings'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountSettingsScreen), findsOneWidget);
    });

    testWidgets('its sign out row ends the session', (tester) async {
      _signIn();
      await _pump(tester, MasterScreen(initialIndex: 5));

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(AuthProvider.isSignedIn, isFalse);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
