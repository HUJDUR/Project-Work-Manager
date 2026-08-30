import 'package:flutter/material.dart';

/// Palette taken from the desktop mockups: a light neutral canvas, white cards
/// with hairline borders and a single blue accent used for the active state.
abstract final class AppColors {
  static const canvas = Color(0xFFF6F7F9);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE6E8EC);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const accent = Color(0xFF2563EB);
  static const accentSoft = Color(0xFFEAF1FE);
  static const danger = Color(0xFFB91C1C);
  static const dangerSoft = Color(0xFFFEF2F2);
  static const dangerBorder = Color(0xFFFECACA);

  static const series = <Color>[
    Color(0xFF2563EB),
    Color(0xFF7C9BF5),
    Color(0xFF34A0A4),
    Color(0xFFF59E0B),
    Color(0xFFA855F7),
    Color(0xFFEF6461),
    Color(0xFF10B981),
    Color(0xFF64748B),
    Color(0xFFD946A0),
  ];

  static Color seriesAt(int index) => series[index % series.length];
}

abstract final class AppSpacing {
  static const cardRadius = 12.0;
  static const gap = 16.0;
  static const pagePadding = 24.0;
}

abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        surface: AppColors.surface,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      dividerColor: AppColors.border,
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 400)),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
