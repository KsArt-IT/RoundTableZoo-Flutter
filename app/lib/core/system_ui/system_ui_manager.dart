import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roundtablezoo/core/theme/app_colors.dart';

/// Менеджер для управления системной областью (status bar и navigation bar)
abstract final class SystemUiManager {
  const SystemUiManager._();

  /// Обновляет цвета системной области в зависимости от темы
  static void updateSystemUi(ThemeMode themeMode, Brightness platformBrightness) {
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && platformBrightness == Brightness.dark);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark ? AppColors.navBarDark : AppColors.navBar,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  /// Устанавливает прозрачную системную область
  static void setTransparent() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

  /// Устанавливает системную область для светлой темы
  static void setLight() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.backgroundLight,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.navBar,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  /// Устанавливает системную область для темной темы
  static void setDark() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.backgroundDark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.navBarDark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }
}
