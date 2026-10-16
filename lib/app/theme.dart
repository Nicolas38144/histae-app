import 'package:flutter/material.dart';

// Editorial direction from pictures/exemple_feed.png: paper, ink, serif titles,
// generous cards. Forest and sand replace the reference's coral/pink palette.
class HistaePalette {
  static const ivory = Color(0xfffaf8f3);
  static const paper = Color(0xfffffdf8);
  static const ink = Color(0xff252c28);
  static const forest = Color(0xff345647);
  static const sand = Color(0xffe4dac9);
}

ThemeData histaeTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: HistaePalette.forest,
    brightness: brightness,
  );
  final colors = base.copyWith(
    primary: dark ? const Color(0xffb1cbbb) : HistaePalette.forest,
    onPrimary: dark ? const Color(0xff182c22) : Colors.white,
    surface: dark ? const Color(0xff1d2420) : HistaePalette.ivory,
    onSurface: dark ? const Color(0xfff2eee4) : HistaePalette.ink,
    onSurfaceVariant: dark ? const Color(0xffc6cec5) : const Color(0xff5a625a),
    surfaceContainerLow: dark ? const Color(0xff272f28) : HistaePalette.paper,
    surfaceContainerHighest: dark
        ? const Color(0xff394238)
        : const Color(0xfff0eade),
    outline: dark ? const Color(0xff8c988b) : const Color(0xff7c8578),
    outlineVariant: dark ? const Color(0xff465144) : HistaePalette.sand,
  );
  final baseTheme = ThemeData(useMaterial3: true, colorScheme: colors);
  TextStyle editorial(TextStyle? style, double size) =>
      (style ?? const TextStyle()).copyWith(
        fontFamily: 'DMSerifDisplay',
        fontWeight: FontWeight.w400,
        fontSize: size,
        height: 1.16,
        letterSpacing: -0.4,
      );
  final text = baseTheme.textTheme;
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));
  return baseTheme.copyWith(
    scaffoldBackgroundColor: colors.surface,
    textTheme: text.copyWith(
      headlineLarge: editorial(text.headlineLarge, 38),
      headlineMedium: editorial(text.headlineMedium, 32),
      headlineSmall: editorial(text.headlineSmall, 28),
      titleLarge: editorial(text.titleLarge, 25),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 17, height: 1.55),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 16, height: 1.5),
      bodySmall: text.bodySmall?.copyWith(fontSize: 13, height: 1.45),
      labelLarge: text.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.primary,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleSpacing: 24,
      titleTextStyle: TextStyle(
        fontFamily: text.titleLarge?.fontFamily,
        color: colors.primary,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.7,
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0.8,
      shadowColor: colors.onSurface.withValues(alpha: 0.07),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.65)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant,
      thickness: 1,
      space: 32,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 56),
        shape: shape,
        side: BorderSide(color: colors.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colors.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
    ),
    chipTheme: baseTheme.chipTheme.copyWith(
      backgroundColor: colors.surfaceContainerLow,
      side: BorderSide(color: colors.outlineVariant),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}
