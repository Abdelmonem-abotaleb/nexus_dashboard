import 'package:flutter/material.dart';

class AppTheme {
  static const Color neonBlue = Color(0xFF2D7FF9);
  static const Color neonPurple = Color(0xFF7C5CFC);
  static const Color neonGreen = Color(0xFF00A884);
  static const Color neonPink = Color(0xFFD94F70);
  static const Color neonOrange = Color(0xFFFF9500);

  static ThemeData get darkTheme => _theme(useDark: true);
  static ThemeData get lightTheme => _theme(useDark: false);

  static ThemeData darkThemeWithAccent(Color accent, double intensity) =>
      _theme(useDark: true, accent: accent, glassIntensity: intensity);

  static ThemeData lightThemeWithAccent(Color accent, double intensity) =>
      _theme(useDark: false, accent: accent, glassIntensity: intensity);

  static ThemeData _theme({
    required bool useDark,
    Color accent = neonBlue,
    double glassIntensity = 1,
  }) {
    final base = useDark ? const Color(0xFF0B0F14) : const Color(0xFFF4F6F8);
    final surface = useDark ? const Color(0xFF121820) : Colors.white;
    final card = useDark ? const Color(0xFF18202A) : const Color(0xFFE9EDF2);
    final primaryText = useDark
        ? const Color(0xFFF2F5F8)
        : const Color(0xFF18202A);
    final secondaryText = useDark
        ? const Color(0xFFB2BEC9)
        : const Color(0xFF4A5868);
    final mutedText = useDark
        ? const Color(0xFF8190A0)
        : const Color(0xFF667587);
    final border = useDark ? const Color(0x33FFFFFF) : const Color(0x33445B74);

    return ThemeData(
      useMaterial3: true,
      brightness: useDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: base,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: accent,
            brightness: useDark ? Brightness.dark : Brightness.light,
            surface: surface,
            error: neonPink,
          ).copyWith(
            primary: accent,
            secondary: accent,
            tertiary: accent,
            onSurface: primaryText,
            outlineVariant: border,
          ),
      fontFamily: 'Segoe UI',
      extensions: [NexusVisualTheme(glassIntensity: glassIntensity)],
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: primaryText,
          fontSize: 72,
          fontWeight: FontWeight.w300,
          letterSpacing: -2,
        ),
        displayMedium: TextStyle(
          color: primaryText,
          fontSize: 48,
          fontWeight: FontWeight.w300,
          letterSpacing: -1,
        ),
        headlineLarge: TextStyle(
          color: primaryText,
          fontSize: 32,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          color: primaryText,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: primaryText, fontSize: 16),
        bodyMedium: TextStyle(color: secondaryText, fontSize: 14),
        labelSmall: TextStyle(
          color: mutedText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: card.withValues(alpha: useDark ? .78 : .88),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card.withValues(alpha: .66),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static LinearGradient backgroundGradient(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0xFF0B0F14), Color(0xFF101722), Color(0xFF0B0F14)]
          : const [Color(0xFFF7F9FB), Color(0xFFEEF2F6), Color(0xFFFFFFFF)],
    );
  }

  static Color accent(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static BoxDecoration glassDecoration(
    BuildContext context, {
    double borderRadius = 16,
    Color? borderColor,
    List<Color>? gradientColors,
  }) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final intensity =
        theme.extension<NexusVisualTheme>()?.glassIntensity ?? 1.0;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors:
            gradientColors ??
            (dark
                ? [
                    Colors.white.withValues(alpha: .055 * intensity),
                    Colors.white.withValues(alpha: .025 * intensity),
                  ]
                : [
                    Colors.white.withValues(
                      alpha: (.8 * intensity).clamp(.2, 1),
                    ),
                    Colors.white.withValues(
                      alpha: (.5 * intensity).clamp(.2, 1),
                    ),
                  ]),
      ),
      border: Border.all(
        color: borderColor ?? theme.colorScheme.outlineVariant,
      ),
    );
  }
}

@immutable
class NexusVisualTheme extends ThemeExtension<NexusVisualTheme> {
  final double glassIntensity;
  const NexusVisualTheme({required this.glassIntensity});

  @override
  NexusVisualTheme copyWith({double? glassIntensity}) =>
      NexusVisualTheme(glassIntensity: glassIntensity ?? this.glassIntensity);

  @override
  NexusVisualTheme lerp(covariant NexusVisualTheme? other, double t) {
    if (other == null) return this;
    return NexusVisualTheme(
      glassIntensity:
          glassIntensity + (other.glassIntensity - glassIntensity) * t,
    );
  }
}
