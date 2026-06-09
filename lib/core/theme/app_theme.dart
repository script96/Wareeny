import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.calmBlue,
      brightness: Brightness.light,
    );
    return _buildTheme(scheme);
  }

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.calmBlue,
      onPrimary: AppColors.textPrimary,
      secondary: AppColors.guardianGreen,
      onSecondary: AppColors.textPrimary,
      error: AppColors.dangerRed,
      onError: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      primaryContainer: AppColors.surfaceAlt,
      onPrimaryContainer: AppColors.textPrimary,
      secondaryContainer: AppColors.surfaceMuted,
      onSecondaryContainer: AppColors.textPrimary,
      errorContainer: AppColors.emergencyCrimson,
      onErrorContainer: AppColors.textPrimary,
      outline: AppColors.outline,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppColors.paper,
      onInverseSurface: AppColors.ink,
      inversePrimary: AppColors.focusRing,
    );

    return _buildTheme(scheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    final textTheme = isDark
        ? Typography.material2021().white.apply(
            bodyColor: colorScheme.onSurface,
            displayColor: colorScheme.onSurface,
          )
        : Typography.material2021().black.apply(
            bodyColor: colorScheme.onSurface,
            displayColor: colorScheme.onSurface,
          );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.midnight,
      canvasColor: AppColors.midnight,
      dividerColor: AppColors.outline,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        disabledColor: AppColors.surfaceMuted,
        selectedColor: AppColors.calmBlue.withValues(alpha: 0.2),
        secondarySelectedColor: AppColors.guardianGreen.withValues(alpha: 0.2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          side: const BorderSide(color: AppColors.outline),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.md),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          minimumSize: const Size(64, 56),
          side: const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.md),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.textPrimary;
          }
          return AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.calmBlue;
          }
          return AppColors.surfaceMuted;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        height: 78,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppColors.calmBlue.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
    );
  }
}
