import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'layouts/master_screen.dart';
import 'providers/providers.dart';
import 'screens/login_screen.dart';
import 'utils/app_theme.dart';

/// Set this to true only for a local, throwaway debugging session, to skip
/// [LoginScreen] and open straight on [MasterScreen] as the seeded
/// administrator — the API side has its own switch,
/// `pwm.WebAPI/DevSettings.BypassAuthentication`, which must stay off too.
const bool bypassLogin = false;
const String _devEmail = 'nadir.hujdur@pwm.ba';
const String _devPassword = 'test';

/// The window the app opens in. The OS title bar is hidden because the app draws
/// its own into the top bar - see `layouts/window_chrome.dart`.
const _windowSize = Size(1280, 800);
const _windowOptions = WindowOptions(
  size: _windowSize,
  minimumSize: Size(1100, 700),
  title: 'Project Work Manager',
  backgroundColor: Colors.transparent,
  titleBarStyle: TitleBarStyle.hidden,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Shown only once it is sized, positioned and stripped of its title bar, so
  // the frame is never on screen.
  unawaited(windowManager.waitUntilReadyToShow(_windowOptions, () async {
    await _centerOnPrimaryDisplay();
    await windowManager.show();
    await windowManager.focus();
  }));

  runApp(
    MultiProvider(
      // One instance per API resource, created on first use. Screens that do their
      // own joining (dashboard, work hours) still build their provider locally.
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => ActivityLogProvider()),
        ChangeNotifierProvider(create: (_) => ActivityLogTypeProvider()),
        ChangeNotifierProvider(create: (_) => CityProvider()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
        ChangeNotifierProvider(create: (_) => CompanyTypeProvider()),
        ChangeNotifierProvider(create: (_) => CountryProvider()),
        ChangeNotifierProvider(create: (_) => MonthlyHourReportProvider()),
        ChangeNotifierProvider(create: (_) => MonthlyHourReportDetailProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => OperationTypeProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => ProjectCategoryProvider()),
        ChangeNotifierProvider(create: (_) => ProjectStatusTypeProvider()),
        ChangeNotifierProvider(create: (_) => TruckLoadProvider()),
        ChangeNotifierProvider(create: (_) => TruckLoadDetailProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => UserOperationProvider()),
        ChangeNotifierProvider(create: (_) => UserTypeProvider()),
        ChangeNotifierProvider(create: (_) => WorkLogProvider()),
        ChangeNotifierProvider(create: (_) => WorkLogDetailProvider()),
      ],
      child: PwmDesktopApp(),
    ),
  );
}

/// window_manager's own `center: true`/`.center()` centers the window on
/// whichever display the mouse cursor happens to be over, not the primary
/// display (see its `calcWindowPosition`). On a multi-monitor setup with
/// differently sized/scaled screens, that can place the window using another
/// monitor's bounds while the OS still opens it on the primary one - landing
/// it mostly off-screen. Centering explicitly on the primary display's own
/// visible area sidesteps that.
Future<void> _centerOnPrimaryDisplay() async {
  final display = await screenRetriever.getPrimaryDisplay();
  final visibleSize = display.visibleSize ?? display.size;
  final visiblePosition = display.visiblePosition ?? Offset.zero;

  final x = visiblePosition.dx + (visibleSize.width - _windowSize.width) / 2;
  final y = visiblePosition.dy + (visibleSize.height - _windowSize.height) / 2;

  await windowManager.setBounds(Rect.fromLTWH(
    x,
    y,
    _windowSize.width,
    _windowSize.height,
  ));
}

class PwmDesktopApp extends StatelessWidget {
  const PwmDesktopApp({super.key});

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
      home: bypassLogin ? _SignedInAsAdmin() : LoginScreen(),
    );
  }
}

/// TEMPORARY companion to [bypassLogin]: signs in as the seeded administrator in
/// the background so the top bar and any future role checks have a real user, and
/// opens the app either way — with the API's own bypass on, no token is needed.
class _SignedInAsAdmin extends StatefulWidget {
  const _SignedInAsAdmin();

  @override
  State<_SignedInAsAdmin> createState() => _SignedInAsAdminState();
}

class _SignedInAsAdminState extends State<_SignedInAsAdmin> {
  late final Future<void> _signIn;

  @override
  void initState() {
    super.initState();
    _signIn = context
        .read<AuthProvider>()
        .login(_devEmail, _devPassword)
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _signIn,
      builder: (context, snapshot) =>
          snapshot.connectionState == ConnectionState.done
              ? MasterScreen()
              : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
