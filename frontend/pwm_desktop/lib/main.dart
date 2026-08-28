import 'package:flutter/material.dart';

import 'layouts/master_screen.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const PwmDesktopApp());
}

class PwmDesktopApp extends StatelessWidget {
  const PwmDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Work Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const MasterScreen(),
    );
  }
}
