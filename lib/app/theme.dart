import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/histae_tokens.dart';

ThemeData histaeTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: HistaeTokens.lavender,
        brightness: brightness,
      ).copyWith(
        primary: dark ? HistaeTokens.lavender : const Color(0xff63429c),
        onPrimary: dark ? HistaeTokens.night : Colors.white,
        primaryContainer: dark
            ? const Color(0xff332b4b)
            : const Color(0xffeae0ff),
        onPrimaryContainer: dark ? HistaeTokens.ink : const Color(0xff291947),
        secondary: dark ? HistaeTokens.coral : const Color(0xff954a39),
        onSecondary: dark ? HistaeTokens.night : Colors.white,
        secondaryContainer: dark ? HistaeTokens.plum : const Color(0xfff7e6df),
        onSecondaryContainer: dark ? HistaeTokens.ink : const Color(0xff47242c),
        surface: dark ? HistaeTokens.night : const Color(0xfffaf8fc),
        onSurface: dark ? HistaeTokens.ink : const Color(0xff1c2030),
        onSurfaceVariant: dark ? HistaeTokens.muted : const Color(0xff5e576d),
        surfaceContainerLowest: dark ? const Color(0xff0b111c) : Colors.white,
        surfaceContainerLow: dark ? HistaeTokens.panel : Colors.white,
        surfaceContainer: dark
            ? HistaeTokens.nightSoft
            : const Color(0xfff0ebf6),
        surfaceContainerHigh: dark
            ? const Color(0xff20283a)
            : const Color(0xffece5f4),
        surfaceContainerHighest: dark
            ? const Color(0xff303247)
            : const Color(0xffe6ddef),
        outline: dark ? const Color(0xff8e879e) : const Color(0xff7d738a),
        outlineVariant: dark ? HistaeTokens.line : const Color(0xffdbd3e5),
        error: dark ? const Color(0xffffb4a5) : const Color(0xffa13229),
        onError: dark ? const Color(0xff48130e) : Colors.white,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    fontFamily: HistaeTokens.sans,
  );
  TextStyle serif(
    TextStyle? style,
    double size, {
    FontWeight weight = FontWeight.w400,
  }) => (style ?? const TextStyle()).copyWith(
    fontFamily: HistaeTokens.serif,
    fontSize: size,
    fontWeight: weight,
    height: 1.1,
    letterSpacing: -size * 0.04,
    fontVariations: const [FontVariation('opsz', 40)],
  );
  final text = base.textTheme;
  final textTheme = text.copyWith(
    displayLarge: serif(text.displayLarge, 54),
    displayMedium: serif(text.displayMedium, 46),
    displaySmall: serif(text.displaySmall, 42),
    headlineLarge: serif(text.headlineLarge, 38),
    headlineMedium: serif(text.headlineMedium, 32),
    headlineSmall: serif(text.headlineSmall, 28),
    titleLarge: serif(text.titleLarge, 25, weight: FontWeight.w500),
    titleMedium: text.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: text.bodyLarge?.copyWith(fontSize: 17, height: 1.55),
    bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.55),
    bodySmall: text.bodySmall?.copyWith(fontSize: 13, height: 1.5),
    labelLarge: text.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: text.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: text.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.3,
    ),
  );
  final panelShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(HistaeTokens.panelRadius),
    side: BorderSide(color: colors.outlineVariant),
  );
  const pill = StadiumBorder();
  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brightness,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 24,
      toolbarHeight: 64,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        color: colors.onSurface,
        fontSize: 18,
      ),
      iconTheme: IconThemeData(color: colors.onSurfaceVariant, size: 22),
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: panelShape,
      clipBehavior: Clip.antiAlias,
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant,
      thickness: 1,
      space: 32,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: pill,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            backgroundColor: colors.primary.withValues(
              alpha: dark ? 0.08 : 0.05,
            ),
            disabledForegroundColor: colors.onSurface.withValues(alpha: 0.38),
            disabledBackgroundColor: colors.onSurface.withValues(alpha: 0.03),
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            textStyle: textTheme.labelLarge,
          ).copyWith(
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) {
                return const BorderSide(color: HistaeTokens.focus, width: 2);
              }
              return BorderSide(
                color: colors.primary.withValues(
                  alpha: states.contains(WidgetState.disabled) ? 0.07 : 0.22,
                ),
              );
            }),
          ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primary,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colors.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      helperStyle: textTheme.bodySmall?.copyWith(
        color: colors.onSurfaceVariant,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: colors.primary.withValues(alpha: dark ? 0.08 : 0.05),
      side: BorderSide(color: colors.primary.withValues(alpha: 0.25)),
      labelStyle: textTheme.bodySmall?.copyWith(color: colors.onSurface),
      shape: pill,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.primary,
      titleTextStyle: textTheme.titleMedium?.copyWith(color: colors.onSurface),
      subtitleTextStyle: textTheme.bodySmall?.copyWith(
        color: colors.onSurfaceVariant,
      ),
      minVerticalPadding: 12,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: panelShape,
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        color: colors.onSurface,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: panelShape,
      textStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.surfaceContainerHigh,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
      actionTextColor: colors.primary,
      behavior: SnackBarBehavior.floating,
      shape: panelShape,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: colors.outlineVariant,
      borderRadius: BorderRadius.circular(4),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.primary,
      selectionColor: colors.primary.withValues(alpha: 0.3),
      selectionHandleColor: colors.primary,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
}
