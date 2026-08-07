import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radius.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.coral,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.coral,
          onPrimary: AppColors.navy,
          secondary: AppColors.sage,
          onSecondary: AppColors.navy,
          surface: AppColors.white,
          onSurface: AppColors.navy,
          // no separate red "error" accent - reuses the same coral as
          // primary, so destructive/error UI stays inside the app's own
          // palette instead of Material's default red
          error: AppColors.coral,
          onError: AppColors.navy,
        ),
        scaffoldBackground: AppColors.offWhite,
        cardColor: AppColors.white,
        textPrimary: AppColors.navy,
        textSecondary: AppColors.grayDark,
        // navy at low opacity rather than a dedicated named color - see
        // AppColors' own docblock
        divider: AppColors.navy.withValues(alpha: 0.08),
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.coral,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.coral,
          onPrimary: AppColors.navy,
          secondary: AppColors.sage,
          onSecondary: AppColors.navy,
          // navyLight, not navy - Material 3's colorScheme.surface is what
          // most components actually paint (WatchlistItemRow and friends
          // use it directly, not cardColor) - leaving it equal to the
          // scaffold background made every "card" blend invisibly into the
          // page instead of standing out from it
          surface: AppColors.navyLight,
          onSurface: AppColors.white,
          error: AppColors.coral,
          onError: AppColors.navy,
        ),
        scaffoldBackground: AppColors.navy,
        cardColor: AppColors.navyLight,
        textPrimary: AppColors.white,
        textSecondary: AppColors.grayLight,
        divider: AppColors.grayLight.withValues(alpha: 0.16),
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color divider,
  }) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    var textTheme = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    textTheme = textTheme.copyWith(
      headlineLarge: GoogleFonts.fraunces(
        textStyle: textTheme.headlineLarge,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.fraunces(
        textStyle: textTheme.headlineMedium,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.fraunces(
        textStyle: textTheme.headlineSmall,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.fraunces(
        textStyle: textTheme.titleLarge,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(color: textSecondary),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      cardColor: cardColor,
      dividerColor: divider,
      dividerTheme: DividerThemeData(color: divider),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      // without this, OutlinedButton falls back to Material 3's own
      // defaults (a plain colorScheme.outline border, ~20dp corners) -
      // visibly different from FilledButton's shape above and from every
      // call site that was manually re-styling itself to compensate (see
      // e.g. SeriesDetailScreen's _ToggleButton docblock). One shared
      // definition here instead of repeating the same styleFrom() call
      // at every outlined button in the app.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffoldBackground,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : textSecondary,
          ),
        ),
      ),
    );
  }
}
