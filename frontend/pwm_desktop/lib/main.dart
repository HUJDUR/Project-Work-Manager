import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'layouts/master_screen.dart';
import 'providers/providers.dart';
import 'screens/login_screen.dart';
import 'utils/app_theme.dart';

/// TEMPORARY: sign-in is on hold while the rest of the app is built, so the app
/// opens straight on [MasterScreen] as the seeded administrator. Set this to
/// false to get [LoginScreen] back — nothing else has to change.
/// The API side has its own switch, `pwm.WebAPI/DevSettings.BypassAuthentication`.
const bool bypassLogin = true;
const String _devEmail = 'admin@pwm.ba';
const String _devPassword = 'test';

void main() {
  runApp(
    MultiProvider(
      // One instance per API resource, created on first use. Screens that do their
      // own joining (dashboard, work hours) still build their provider locally.
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
      child: const PwmDesktopApp(),
    ),
  );
}

class PwmDesktopApp extends StatelessWidget {
  const PwmDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Work Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: bypassLogin ? const _SignedInAsAdmin() : const LoginScreen(),
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
              ? const MasterScreen()
              : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
