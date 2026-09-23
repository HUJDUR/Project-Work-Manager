import 'package:flutter/material.dart';

/// One theme's colours, kept token for token with the desktop app's
/// `utils/app_theme.dart` so the two halves of PWM read as one product. The
/// light one is the palette the mobile mockups use — a white canvas, cards with
/// hairline borders and a single blue accent — and the dark one answers it.
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
    required this.success,
    required this.fieldBorder,
    required this.fieldFill,
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

  /// The wash behind an accent icon — the round badge on every summary tile.
  final Color accentSoft;

  final Color danger;
  final Color dangerSoft;
  final Color dangerBorder;

  /// The one green in either palette - a saved/succeeded toast's top line,
  /// nothing else. [accent] stays the app's one "primary" blue everywhere
  /// else, so this is never reached for a button or a link.
  final Color success;

  final Color fieldBorder;

  /// The ground inside an input. The desktop fills its fields with the page's
  /// grey canvas, which works there because its cards are white on grey; here
  /// the canvas *is* white, so the tint has to be its own token or every field
  /// would be white on white and read as nothing but an outline.
  final Color fieldFill;

  /// How strongly a status chip's own colour washes its background. Dark needs
  /// more of it to read against a dark card.
  final double chipTint;

  bool get isDark => brightness == Brightness.dark;

  static const light = AppPalette(
    brightness: Brightness.light,
    // The mockup's canvas is white, not the desktop's light grey: a phone shows
    // one card at a time, so the cards are separated by their borders instead.
    canvas: Color(0xFFFFFFFF),
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
    success: Color(0xFF10B981),
    fieldBorder: Color(0xFFDCE0E6),
    // The grey the desktop uses for its page, borrowed for the field itself.
    fieldFill: Color(0xFFF6F7F9),
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
    success: Color(0xFF34D399),
    fieldBorder: Color(0xFF323945),
    // A shade *below* the card, so a field reads as a well rather than a raised tile.
    fieldFill: Color(0xFF12161B),
    chipTint: 0.20,
  );
}

/// The palette in force, read as `AppColors.canvas` from every screen.
///
/// These are **getters over mutable state**, not constants: the app runs one
/// theme at a time and [ThemeController] swaps [palette] before it tells the
/// tree to rebuild. That is why nothing in this project's widget tree is
/// `const` — a const widget keeps the colour it was first built with.
abstract final class AppColors {
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
  static Color get accent => palette.accent;
  static Color get accentSoft => palette.accentSoft;
  static Color get danger => palette.danger;
  static Color get dangerSoft => palette.dangerSoft;
  static Color get dangerBorder => palette.dangerBorder;
  static Color get success => palette.success;
  static Color get fieldBorder => palette.fieldBorder;
  static Color get fieldFill => palette.fieldFill;

  /// A status chip built from the one colour that names its state rather than
  /// from a hand-picked pair, so both themes get it right — the desktop's rule,
  /// and the reason a chip stores an accent and nothing else.
  static (Color background, Color foreground) chip(Color accent) {
    if (!palette.isDark) {
      return (accent.withValues(alpha: palette.chipTint), accent);
    }

    // A mid-dark accent has to be lifted to stay legible on a dark chip.
    final lifted = Color.lerp(accent, Colors.white, 0.32)!;
    return (lifted.withValues(alpha: palette.chipTint), lifted);
  }
}

abstract final class AppSpacing {
  static const cardRadius = 12.0;
  static const gap = 16.0;

  /// Narrower than the desktop's 24: a phone cannot spare it.
  static const pagePadding = 16.0;
}

/// Which theme is on. It swaps [AppColors.palette] **before** notifying, so by
/// the time the tree rebuilds every `AppColors.x` already answers the new
/// theme. The choice is not persisted — it lasts as long as the process does.
class ThemeController extends ChangeNotifier {
  /// The shop floor runs this on bright displays too, so it opens dark the
  /// same as the desktop; the top bar's toggle is there for whoever wants
  /// otherwise.
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
  static OutlineInputBorder _outline(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: color, width: width),
      );

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
        filled: true,
        fillColor: palette.fieldFill,
        hintStyle: TextStyle(color: palette.textMuted),
        // Touch targets: a phone's fields are taller than the desktop's 15.
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        errorStyle: TextStyle(fontSize: 12, color: palette.danger),
        enabledBorder: _outline(palette.fieldBorder),
        border: _outline(palette.fieldBorder),
        disabledBorder: _outline(palette.border),
        // A focus ring, not a second frame — Material's default doubles to 2.
        focusedBorder: _outline(palette.accent, width: 1.4),
        errorBorder: _outline(palette.danger),
        focusedErrorBorder: _outline(palette.danger, width: 1.4),
      ),
    );
  }
}

/// The bordered white panel every screen is built from.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

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
