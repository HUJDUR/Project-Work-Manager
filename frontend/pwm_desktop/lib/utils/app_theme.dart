import 'package:flutter/material.dart';

/// One theme's colours. The light one is the palette taken from the desktop
/// mockups — a light neutral canvas, white cards with hairline borders and a
/// single blue accent — and the dark one answers it token for token.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.dangerSoft,
    required this.dangerBorder,
    required this.tooltipSurface,
    required this.tooltipText,
    required this.chipTint,
  });

  final Brightness brightness;

  final Color canvas;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final Color danger;
  final Color dangerSoft;
  final Color dangerBorder;

  /// A tooltip floats over the chart, so it cannot borrow the card's colours:
  /// in light it inverts to a dark slate, and in dark it lifts clear of the
  /// card rather than going near-white the way `textPrimary` would.
  final Color tooltipSurface;
  final Color tooltipText;

  /// How strongly a status chip's own colour washes its background. Dark needs
  /// more of it to read against a dark card.
  final double chipTint;

  bool get isDark => brightness == Brightness.dark;

  static const light = AppPalette(
    brightness: Brightness.light,
    canvas: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE6E8EC),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    textMuted: Color(0xFF9CA3AF),
    accent: Color(0xFF2563EB),
    accentSoft: Color(0xFFEAF1FE),
    danger: Color(0xFFB91C1C),
    dangerSoft: Color(0xFFFEF2F2),
    dangerBorder: Color(0xFFFECACA),
    tooltipSurface: Color(0xFF1F2937),
    tooltipText: Color(0xFFF9FAFB),
    chipTint: 0.12,
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    canvas: Color(0xFF101317),
    surface: Color(0xFF181C22),
    border: Color(0xFF2A3038),
    textPrimary: Color(0xFFE8EBEF),
    textSecondary: Color(0xFFA0A8B4),
    textMuted: Color(0xFF7A838F),
    // Brighter than the light accent: the same blue goes muddy on a dark ground.
    accent: Color(0xFF5C9DFF),
    accentSoft: Color(0xFF1E2A3D),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF2E1A1A),
    dangerBorder: Color(0xFF5B2A2A),
    tooltipSurface: Color(0xFF333B47),
    tooltipText: Color(0xFFF2F4F7),
    chipTint: 0.20,
  );
}

/// The palette in force, read as `AppColors.canvas` from every screen.
///
/// These are **getters over mutable state**, not constants: the app has one
/// window and one theme, and [ThemeController] swaps [palette] before it tells
/// the tree to rebuild. That is why almost nothing in the widget tree is
/// `const` any more — a const widget would keep the colour it was built with.
abstract final class AppColors {
  /// Starts on [defaultMode]'s palette, and [ThemeController] keeps it in step.
  static AppPalette palette = paletteFor(ThemeController.defaultMode);

  static AppPalette paletteFor(ThemeMode mode) =>
      mode == ThemeMode.dark ? AppPalette.dark : AppPalette.light;

  static bool get isDark => palette.isDark;

  static Color get canvas => palette.canvas;
  static Color get surface => palette.surface;
  static Color get border => palette.border;
  static Color get textPrimary => palette.textPrimary;
  static Color get textSecondary => palette.textSecondary;
  static Color get textMuted => palette.textMuted;
  static Color get tooltipSurface => palette.tooltipSurface;
  static Color get tooltipText => palette.tooltipText;
  static Color get accent => palette.accent;
  static Color get accentSoft => palette.accentSoft;
  static Color get danger => palette.danger;
  static Color get dangerSoft => palette.dangerSoft;
  static Color get dangerBorder => palette.dangerBorder;

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

  /// A status chip, built from the one colour that names its state rather than
  /// from a hand-picked pair, so both themes get it right. In light this lands
  /// within a shade of the pastels the mockups use.
  static (Color background, Color foreground) chip(Color accent) {
    if (!palette.isDark) {
      return (accent.withValues(alpha: palette.chipTint), accent);
    }

    // A mid-dark accent has to be lifted to stay legible on a dark chip.
    final lifted = Color.lerp(accent, Colors.white, 0.32)!;
    return (lifted.withValues(alpha: palette.chipTint), lifted);
  }

  /// The neutral chip — a state with no colour of its own.
  static Color get neutralChip => palette.isDark
      ? const Color(0xFF9AA3AE)
      : const Color(0xFF4B5563);
}

abstract final class AppSpacing {
  static const cardRadius = 12.0;
  static const gap = 16.0;
  static const pagePadding = 24.0;
}

/// Which theme is on. It swaps [AppColors.palette] **before** notifying, so by
/// the time the tree rebuilds every `AppColors.x` already answers the new
/// theme. The choice is not persisted — it lasts as long as the window does.
class ThemeController extends ChangeNotifier {
  /// The shop floor runs these screens on bright displays in a dark hall, so
  /// the app opens dark and the toggle is there for whoever wants otherwise.
  static const ThemeMode defaultMode = ThemeMode.dark;

  ThemeMode _mode = defaultMode;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void toggle() => setMode(isDark ? ThemeMode.light : ThemeMode.dark);

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;

    _mode = mode;
    AppColors.palette = AppColors.paletteFor(mode);
    notifyListeners();
  }
}

abstract final class AppTheme {
  static ThemeData light() => _build(AppPalette.light);

  static ThemeData dark() => _build(AppPalette.dark);

  static ThemeData _build(AppPalette palette) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: palette.brightness,
        surface: palette.surface,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.surface,
      dividerColor: palette.border,
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        // Fields sit on cards, so they take the card's own ground.
        fillColor: palette.surface,
        hintStyle: TextStyle(color: palette.textMuted),
      ),
      tooltipTheme:
          const TooltipThemeData(waitDuration: Duration(milliseconds: 400)),
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
