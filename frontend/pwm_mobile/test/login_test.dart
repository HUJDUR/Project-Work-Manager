import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pwm_mobile/models/user.dart';
import 'package:pwm_mobile/providers/auth_provider.dart';
import 'package:pwm_mobile/screens/login_screen.dart';
import 'package:pwm_mobile/utils/api_client_exception.dart';

/// Stands in for the real provider so the screen can be driven without an API.
class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider({this.failWith});

  final String? failWith;

  final List<({String email, String password})> calls = [];

  @override
  Future<void> login(String email, String password) async {
    calls.add((email: email.trim(), password: password));

    if (failWith != null) {
      throw ApiClientException(failWith!);
    }

    AuthProvider.accesstoken = 'token';
    AuthProvider.user = const User(
      id: 36,
      name: 'Muhamed',
      surname: 'Ramic',
      email: 'muhamed.ramic@pwm.ba',
      userTypeId: 5,
      isActive: true,
    );
    AuthProvider.role = 'Production worker';
  }
}

/// A small phone, so the form is checked at the width it ships on.
const _phone = Size(390, 844);

Future<void> _pumpLogin(
  WidgetTester tester,
  AuthProvider auth, {
  VoidCallback? onSignedIn,
}) async {
  tester.view
    ..physicalSize = _phone
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(home: LoginScreen(onSignedIn: onSignedIn)),
    ),
  );
}

Future<void> _signIn(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.tap(find.text('Sign in').last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AuthProvider.accesstoken = null;
    AuthProvider.refreshtoken = null;
    AuthProvider.user = null;
    AuthProvider.role = '';
  });

  testWidgets('does not call the API until both fields are filled', (tester) async {
    final auth = _FakeAuthProvider();
    await _pumpLogin(tester, auth);

    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('rejects an address that is not one', (tester) async {
    final auth = _FakeAuthProvider();
    await _pumpLogin(tester, auth);

    await _signIn(tester, 'muhamed', 'test');

    expect(find.text('That does not look like an email address.'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('shows the wording the API refused the credentials with',
      (tester) async {
    // What `/Access/Login` actually answers a wrong password with.
    final auth = _FakeAuthProvider(failWith: 'Incorrect email or password.');
    await _pumpLogin(tester, auth);

    await _signIn(tester, 'muhamed.ramic@pwm.ba', 'wrong');

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(AuthProvider.isSignedIn, isFalse);
  });

  testWidgets('signs in with the typed credentials and moves on', (tester) async {
    final auth = _FakeAuthProvider();
    var signedIn = false;

    await _pumpLogin(tester, auth, onSignedIn: () => signedIn = true);
    await _signIn(tester, '  muhamed.ramic@pwm.ba ', 'test');

    expect(auth.calls, [(email: 'muhamed.ramic@pwm.ba', password: 'test')]);
    expect(signedIn, isTrue);
    expect(AuthProvider.isSignedIn, isTrue);
    expect(AuthProvider.user?.fullName, 'Muhamed Ramic');
  });

  testWidgets('a failed sign-in leaves the form usable for another go',
      (tester) async {
    final auth = _FakeAuthProvider(failWith: 'Incorrect email or password.');
    await _pumpLogin(tester, auth);

    await _signIn(tester, 'muhamed.ramic@pwm.ba', 'wrong');
    await _signIn(tester, 'muhamed.ramic@pwm.ba', 'wrong-again');

    // The button is live again rather than stuck on its spinner.
    expect(auth.calls.length, 2);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('hides the password until the eye is tapped', (tester) async {
    await _pumpLogin(tester, _FakeAuthProvider());

    expect(find.byTooltip('Show password'), findsOneWidget);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('survives a viewport shorter than its own padding', (tester) async {
    // The centring works off the height left over after padding, which goes
    // negative on a viewport this short — a zero-height layout pass at startup,
    // or a keyboard over a small screen. A negative minimum is an assertion, and
    // a phone-sized surface never reaches it, so it is pumped explicitly.
    tester.view
      ..physicalSize = const Size(390, 40)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuthProvider(),
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the whole form fits a phone without overflowing', (tester) async {
    await _pumpLogin(tester, _FakeAuthProvider());
    await tester.pumpAndSettle();

    expect(find.text('Project Work Manager'), findsOneWidget);
    expect(find.text('Use your Project Work Manager account.'), findsOneWidget);
    // The heading and the button, the same pair the desktop shows.
    expect(find.text('Sign in'), findsNWidgets(2));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
