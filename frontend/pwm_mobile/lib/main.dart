import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'layouts/master_screen.dart';
import 'providers/providers.dart';
import 'screens/login_screen.dart';
import 'utils/api_client_exception.dart';
import 'utils/app_theme.dart';

/// Skips [LoginScreen] and comes up already signed in as [_devEmail], so a
/// screen several taps in is one hot restart away. Set this to false to get
/// sign-in back — the screen is built and nothing else has to change.
/// The API side has its own switch, `pwm.WebAPI/DevSettings.BypassAuthentication`,
/// which stops endpoints checking the token but does **not** stop `/Access/Login`
/// checking the password, so this is still a real sign-in.
const bool bypassLogin = true;

/// Faruk Tufekcic, a seeded production worker (Painter, id 20) — picked once at
/// random from the active shop floor and **kept**, so every run shows the same
/// hours and a screen's numbers can be checked against the API by hand. The
/// seeder generates these names from a seeded `Random`, so a database reseeded
/// from different data means picking again.
const String _devEmail = 'faruk.tufekcic@pwm.ba';
const String _devPassword = 'test';

void main() {
  runApp(
    MultiProvider(
      // One instance per API resource, created on first use. The dashboard does
      // its own joining, so it still builds its provider locally.
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => WorkLogDetailProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => OperationTypeProvider()),
        ChangeNotifierProvider(create: (_) => ProjectStatusTypeProvider()),
        ChangeNotifierProvider(create: (_) => UserOperationProvider()),
        ChangeNotifierProvider(create: (_) => WorkLogProvider()),
      ],
      child: PwmMobileApp(),
    ),
  );
}

class PwmMobileApp extends StatelessWidget {
  const PwmMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The controller swaps AppColors.palette before it notifies, so by the time
    // this rebuilds every AppColors.x already answers the new theme.
    final mode = context.watch<ThemeController>().mode;

    return MaterialApp(
      title: 'Project Work Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: bypassLogin ? _SignedInAsWorker() : LoginScreen(),
    );
  }
}

/// Companion to [bypassLogin]: signs in as the seeded worker in the background
/// so the app comes up on the dashboard with real hours to total.
///
/// It **must not** open the shell when that sign-in failed. It used to, on the
/// grounds that the API's own bypass means no token is needed — but the screens
/// need a *user*, not a token, and a shell with no session shows the dashboard's
/// "No account is signed in." with nothing to say what actually went wrong. The
/// usual cause is that the API cannot be reached at all — see
/// [BaseProvider.baseUrl] for why `localhost` is the wrong address on Android.
class _SignedInAsWorker extends StatefulWidget {
  const _SignedInAsWorker();

  @override
  State<_SignedInAsWorker> createState() => _SignedInAsWorkerState();
}

class _SignedInAsWorkerState extends State<_SignedInAsWorker> {
  late Future<void> _signIn;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final auth = context.read<AuthProvider>();
    // Off the first frame: `login` flips its busy flag and notifies straight
    // away, and a provider that notifies while the tree is still building
    // throws. A microtask runs once this build has finished.
    _signIn = Future.microtask(() => auth.login(_devEmail, _devPassword));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _signIn,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return _DevSignInFailed(
            message: snapshot.error is ApiClientException
                ? (snapshot.error as ApiClientException).message
                : 'Could not reach the API at ${BaseProvider.baseUrl}',
            onRetry: () => setState(_start),
          );
        }

        return MasterScreen();
      },
    );
  }
}

/// Says why the shortcut did not work and offers the ordinary way in, rather
/// than dropping the user into an app with no session behind it.
class _DevSignInFailed extends StatelessWidget {
  const _DevSignInFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined, size: 38, color: AppColors.textMuted),
                const SizedBox(height: 12),
                const Text(
                  'Could not sign in as the dev worker',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => LoginScreen()),
                      ),
                      child: const Text('Sign in instead'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
