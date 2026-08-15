import 'package:flutter/material.dart';
import 'package:roundtablezoo/core/theme/app_colors.dart';
import 'package:roundtablezoo/core/theme/app_text_style.dart';

/// Light and dark application themes.
abstract final class AppTheme {
  static ThemeData get light => _build(.light);

  static ThemeData get dark => _build(.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == .dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: .floating),
      textTheme: TextTheme(
        displayLarge: isDark
            ? AppTextStyles.display.copyWith(fontSize: 38, color: AppColors.textLight)
            : AppTextStyles.display.copyWith(fontSize: 38),
        displayMedium: isDark
            ? AppTextStyles.display.copyWith(color: AppColors.textLight)
            : AppTextStyles.display,
        displaySmall: isDark
            ? AppTextStyles.display.copyWith(fontSize: 28, color: AppColors.textLight)
            : AppTextStyles.display.copyWith(fontSize: 28),
        headlineLarge: isDark
            ? AppTextStyles.headlineLarge.copyWith(color: AppColors.textLight)
            : AppTextStyles.headlineLarge,
        headlineMedium: isDark
            ? AppTextStyles.headlineMedium.copyWith(color: AppColors.textLight)
            : AppTextStyles.headlineMedium,
        headlineSmall: isDark
            ? AppTextStyles.headlineSmall.copyWith(color: AppColors.textLight)
            : AppTextStyles.headlineSmall,
        titleLarge: isDark
            ? AppTextStyles.titleLarge.copyWith(color: AppColors.textLight)
            : AppTextStyles.titleLarge,
        titleMedium: isDark
            ? AppTextStyles.titleMedium.copyWith(color: AppColors.textLight)
            : AppTextStyles.titleMedium,
        titleSmall: isDark
            ? AppTextStyles.titleSmall.copyWith(color: AppColors.textLight)
            : AppTextStyles.titleSmall,
        bodyLarge: isDark
            ? AppTextStyles.bodyLarge.copyWith(color: AppColors.textLight)
            : AppTextStyles.bodyLarge,
        bodyMedium: isDark
            ? AppTextStyles.bodyMedium.copyWith(color: AppColors.textLight)
            : AppTextStyles.bodyMedium,
        bodySmall: isDark
            ? AppTextStyles.bodySmall.copyWith(color: AppColors.textLight)
            : AppTextStyles.bodySmall,
        labelLarge: isDark
            ? AppTextStyles.label.copyWith(color: AppColors.textLight)
            : AppTextStyles.label,
        labelMedium: isDark
            ? AppTextStyles.label.copyWith(fontSize: 14, color: AppColors.textLight)
            : AppTextStyles.label.copyWith(fontSize: 14),
        labelSmall: isDark
            ? AppTextStyles.label.copyWith(fontSize: 12, color: AppColors.textLight)
            : AppTextStyles.label.copyWith(fontSize: 12),
      ),
    );
  }
}
