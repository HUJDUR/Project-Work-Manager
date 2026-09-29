import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/providers.dart';
import 'screens/login_screen.dart';
import 'utils/app_theme.dart';

/// The root navigator, so an expired session can return to sign-in from
/// wherever the user is - see [AuthProvider.expireSession].
final _navigatorKey = GlobalKey<NavigatorState>();

void _returnToSignIn() => _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(notice: AuthProvider.sessionExpiredMessage),
      ),
      (route) => false,
    );

void main() {
  AuthProvider.onSessionExpired = _returnToSignIn;

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
        ChangeNotifierProvider(create: (_) => ProjectCategoryProvider()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
        ChangeNotifierProvider(create: (_) => UserOperationProvider()),
        ChangeNotifierProvider(create: (_) => WorkLogProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
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
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: LoginScreen(),
    );
  }
}
