import 'package:flutter/material.dart';

class InkTheme {
  static const inkBlack = Color(0xff0d0d0f);
  static const softGray = Color(0xffa7a9ad);
  static const paperWhite = Color(0xfffaf9f6);
  static const paperSurface = Color(0xfffffdf9);
  static const eInkBlue = Color(0xff4c7bd9);
  static const eInkRed = Color(0xffd46a6a);
  static const eInkYellow = Color(0xffe5c35a);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: eInkBlue,
      brightness: Brightness.light,
      primary: eInkBlue,
      secondary: eInkYellow,
      tertiary: eInkRed,
      surface: paperSurface,
      onSurface: inkBlack,
      error: eInkRed,
    );

    final baseText = Typography.material2021().black.apply(
      bodyColor: inkBlack,
      displayColor: inkBlack,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paperWhite,
      fontFamily: null,
      textTheme: baseText.copyWith(
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontSize: 34,
          height: 1.18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontSize: 28,
          height: 1.22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontSize: 24,
          height: 1.25,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          height: 1.45,
          color: inkBlack.withValues(alpha: 0.76),
          letterSpacing: 0,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          height: 1.35,
          color: inkBlack.withValues(alpha: 0.54),
          letterSpacing: 0,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: paperWhite,
        surfaceTintColor: Colors.transparent,
        foregroundColor: inkBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: baseText.titleLarge?.copyWith(
          color: inkBlack,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paperSurface.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        indicatorColor: eInkBlue.withValues(alpha: 0.12),
        elevation: 0,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? eInkBlue
                : inkBlack.withValues(alpha: 0.58),
            size: 23,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: paperSurface,
        elevation: 0,
        shadowColor: inkBlack.withValues(alpha: 0.05),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: inkBlack.withValues(alpha: 0.07)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: TextStyle(color: inkBlack.withValues(alpha: 0.58)),
        helperStyle: TextStyle(color: inkBlack.withValues(alpha: 0.48)),
        prefixIconColor: inkBlack.withValues(alpha: 0.48),
        suffixIconColor: inkBlack.withValues(alpha: 0.48),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: inkBlack.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: eInkBlue, width: 1.35),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: inkBlack.withValues(alpha: 0.07)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: eInkBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: softGray.withValues(alpha: 0.24),
          disabledForegroundColor: inkBlack.withValues(alpha: 0.34),
          elevation: 0,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size(48, 50),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkBlack,
          side: BorderSide(color: inkBlack.withValues(alpha: 0.12)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size(48, 50),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: eInkBlue,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? eInkBlue.withValues(alpha: 0.11)
                : paperSurface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? eInkBlue
                : inkBlack.withValues(alpha: 0.72),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: inkBlack.withValues(alpha: 0.10)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: paperSurface,
        selectedColor: eInkBlue,
        disabledColor: softGray.withValues(alpha: 0.18),
        labelStyle: TextStyle(color: inkBlack.withValues(alpha: 0.72)),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide(color: inkBlack.withValues(alpha: 0.08)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: inkBlack.withValues(alpha: 0.72),
        textColor: inkBlack,
        subtitleTextStyle: baseText.bodySmall,
        titleTextStyle: baseText.titleSmall?.copyWith(
          color: inkBlack,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: eInkBlue,
        linearTrackColor: inkBlack.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : paperSurface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? eInkBlue
              : softGray.withValues(alpha: 0.38),
        ),
        trackOutlineColor: WidgetStatePropertyAll(
          inkBlack.withValues(alpha: 0.08),
        ),
      ),
      dividerTheme: DividerThemeData(color: inkBlack.withValues(alpha: 0.08)),
    );
  }
}
