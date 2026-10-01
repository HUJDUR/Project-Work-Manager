import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:pwm_desktop/providers/auth_provider.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/screens/login_screen.dart';

class _TestProvider extends BaseProvider<Object> {
  @override
  Object fromJson(dynamic data) => throw UnimplementedError();

  _TestProvider() : super('Test');

  /// [send] with a canned answer instead of the network.
  Future<http.Response> answer(int statusCode) =>
      send((_) async => http.Response('', statusCode));
}

void main() {
  late int expiries;

  setUp(() {
    expiries = 0;
    AuthProvider.onSessionExpired = () => expiries++;
    AuthProvider.accesstoken = 'expired-access-token';
    // No refresh token, so the refresh fails without touching the network -
    // the same outcome as the API refusing one.
    AuthProvider.refreshtoken = null;
    AuthProvider.role = 'Admin';
  });

  tearDown(() {
    AuthProvider.onSessionExpired = null;
    AuthProvider.accesstoken = null;
    AuthProvider.role = '';
  });

  test('a 401 the refresh cannot fix ends the session and returns to sign-in', () async {
    await _TestProvider().answer(401);

    expect(expiries, 1);
    expect(AuthProvider.isSignedIn, isFalse);
    expect(AuthProvider.role, isEmpty);
  });

  test('requests failing together return to sign-in only once', () async {
    final provider = _TestProvider();

    await Future.wait([provider.answer(401), provider.answer(401), provider.answer(401)]);

    expect(expiries, 1);
  });

  test('a 401 with no session to end does not navigate', () async {
    AuthProvider.accesstoken = null;

    await _TestProvider().answer(401);

    expect(expiries, 0);
  });

  test('any other answer leaves the session alone', () async {
    await _TestProvider().answer(403);

    expect(expiries, 0);
    expect(AuthProvider.isSignedIn, isTrue);
  });

  testWidgets('the sign-in screen says why the user is back', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(home: LoginScreen(notice: AuthProvider.sessionExpiredMessage)),
    ));

    expect(find.text(AuthProvider.sessionExpiredMessage), findsOneWidget);
  });
}
