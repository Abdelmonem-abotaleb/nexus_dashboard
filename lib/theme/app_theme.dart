import 'package:flutter/material.dart';

class AppTheme {
  static bool useDarkMode = true;
  static double glassIntensity = 1.0;

  // Neon accent colors
  static const Color neonBlue = Color(0xFF00A8E8);
  static const Color neonPurple = Color(0xFF7B2FFF);
  static const Color neonGreen = Color(0xFF00C781);
  static const Color neonPink = Color(0xFFE91E63);

  static Color get darkBase =>
      useDarkMode ? const Color(0xFF050A14) : const Color(0xFFF5F8FC);
  static Color get darkSurface =>
      useDarkMode ? const Color(0xFF0D1626) : const Color(0xFFFFFFFF);
  static Color get darkCard =>
      useDarkMode ? const Color(0xFF111C2E) : const Color(0xFFEAF0F7);
  static Color get glassBorder =>
      useDarkMode ? const Color(0x33FFFFFF) : const Color(0x33445B74);

  static Color get textPrimary =>
      useDarkMode ? const Color(0xFFE8F4FF) : const Color(0xFF142033);
  static Color get textSecondary =>
      useDarkMode ? const Color(0xFF8AAAC8) : const Color(0xFF3F5874);
  static Color get textMuted =>
      useDarkMode ? const Color(0xFF3D5A7A) : const Color(0xFF71859B);

  static ThemeData get darkTheme => _theme(useDark: true);
  static ThemeData get lightTheme => _theme(useDark: false);

  static ThemeData _theme({required bool useDark}) {
    final base = useDark ? const Color(0xFF050A14) : const Color(0xFFF5F8FC);
    final surface = useDark ? const Color(0xFF0D1626) : Colors.white;
    final card = useDark ? const Color(0xFF111C2E) : const Color(0xFFEAF0F7);
    final primaryText = useDark
        ? const Color(0xFFE8F4FF)
        : const Color(0xFF142033);
    final secondaryText = useDark
        ? const Color(0xFF8AAAC8)
        : const Color(0xFF3F5874);
    final mutedText = useDark
        ? const Color(0xFF3D5A7A)
        : const Color(0xFF71859B);
    final border = useDark ? const Color(0x33FFFFFF) : const Color(0x33445B74);

    return ThemeData(
      useMaterial3: true,
      brightness: useDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: base,
      colorScheme: ColorScheme(
        brightness: useDark ? Brightness.dark : Brightness.light,
        primary: neonBlue,
        onPrimary: useDark ? Colors.white : const Color(0xFF06111F),
        secondary: neonPurple,
        onSecondary: Colors.white,
        tertiary: neonGreen,
        onTertiary: const Color(0xFF06111F),
        error: neonPink,
        onError: Colors.white,
        surface: surface,
        onSurface: primaryText,
      ),
      fontFamily: 'Rajdhani',
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
          letterSpacing: 1,
        ),
        headlineMedium: TextStyle(
          color: primaryText,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: secondaryText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: TextStyle(
          color: mutedText,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: card.withValues(alpha: useDark ? 0.7 : 0.82),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
      ),
    );
  }

  static LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: useDarkMode
        ? [darkBase, const Color(0xFF080F1E), const Color(0xFF050A14)]
        : [
            const Color(0xFFF7FAFE),
            const Color(0xFFEAF2FA),
            const Color(0xFFFFFFFF),
          ],
  );

  static LinearGradient get neonBlueGradient => const LinearGradient(
    colors: [neonBlue, neonPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: useDarkMode
        ? [
            Colors.white.withValues(alpha: 0.08 * glassIntensity),
            Colors.white.withValues(alpha: 0.03 * glassIntensity),
          ]
        : [
            Colors.white.withValues(
              alpha: (0.86 * glassIntensity).clamp(0.2, 1.0),
            ),
            Colors.white.withValues(
              alpha: (0.58 * glassIntensity).clamp(0.2, 1.0),
            ),
          ],
  );

  static BoxDecoration glassDecoration({
    double borderRadius = 16,
    Color? borderColor,
    List<Color>? gradientColors,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors:
            gradientColors ??
            (useDarkMode
                ? [
                    Colors.white.withValues(alpha: 0.08 * glassIntensity),
                    Colors.white.withValues(alpha: 0.03 * glassIntensity),
                  ]
                : [
                    Colors.white.withValues(
                      alpha: (0.78 * glassIntensity).clamp(0.2, 1.0),
                    ),
                    Colors.white.withValues(
                      alpha: (0.46 * glassIntensity).clamp(0.2, 1.0),
                    ),
                  ]),
      ),
      border: Border.all(color: borderColor ?? glassBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: useDarkMode
              ? neonBlue.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.08),
          blurRadius: 20,
          spreadRadius: 0,
        ),
      ],
    );
  }

  static BoxDecoration neonGlowDecoration(
    Color glowColor, {
    double borderRadius = 12,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: useDarkMode ? 0.4 : 0.18),
          blurRadius: 20,
          spreadRadius: -4,
        ),
        BoxShadow(
          color: glowColor.withValues(alpha: useDarkMode ? 0.2 : 0.1),
          blurRadius: 40,
          spreadRadius: -8,
        ),
      ],
    );
  }
}
