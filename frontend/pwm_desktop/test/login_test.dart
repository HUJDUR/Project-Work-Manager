import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pwm_desktop/models/user.dart';
import 'package:pwm_desktop/providers/auth_provider.dart';
import 'package:pwm_desktop/screens/login_screen.dart';
import 'package:pwm_desktop/utils/api_client_exception.dart';

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
      id: 1,
      name: 'Nadir',
      surname: 'Hujdur',
      email: 'admin@pwm.ba',
      userTypeId: 1,
      isActive: true,
    );
    AuthProvider.role = 'Administrator';
  }
}

Future<void> _pumpLogin(
  WidgetTester tester,
  AuthProvider auth, {
  VoidCallback? onSignedIn,
}) async {
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

    expect(find.text('Enter your email or username.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('signs in with a username instead of an email', (tester) async {
    final auth = _FakeAuthProvider();
    var signedIn = false;

    await _pumpLogin(tester, auth, onSignedIn: () => signedIn = true);
    await _signIn(tester, 'NadirHujdur', 'test');

    expect(auth.calls, [(email: 'NadirHujdur', password: 'test')]);
    expect(signedIn, isTrue);
  });

  testWidgets('shows the wording the API refused the credentials with', (tester) async {
    final auth = _FakeAuthProvider(failWith: 'Incorrect email or password.');
    await _pumpLogin(tester, auth);

    await _signIn(tester, 'admin@pwm.ba', 'wrong');

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(AuthProvider.isSignedIn, isFalse);
  });

  testWidgets('signs in with the typed credentials and moves on', (tester) async {
    final auth = _FakeAuthProvider();
    var signedIn = false;

    await _pumpLogin(tester, auth, onSignedIn: () => signedIn = true);
    await _signIn(tester, '  admin@pwm.ba ', 'test');

    expect(auth.calls, [(email: 'admin@pwm.ba', password: 'test')]);
    expect(signedIn, isTrue);
    expect(AuthProvider.isSignedIn, isTrue);
    expect(AuthProvider.user?.fullName, 'Nadir Hujdur');
  });

  testWidgets('hides the password until the eye is tapped', (tester) async {
    await _pumpLogin(tester, _FakeAuthProvider());

    expect(find.byTooltip('Show password'), findsOneWidget);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Hide password'), findsOneWidget);
  });
}
