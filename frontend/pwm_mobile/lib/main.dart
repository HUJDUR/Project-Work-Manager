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
      // Only app-wide state lives here; every screen builds the API providers it
      // needs itself.
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
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
