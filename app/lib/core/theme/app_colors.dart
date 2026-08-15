import 'package:flutter/material.dart';

/// Base palette shared by themes and the system UI manager.
abstract final class AppColors {
  const AppColors._();

  /// Seed for Material 3 color schemes.
  static const Color seed = Color(0xFF2E7D6B);

  static const Color backgroundLight = Color(0xFFF8FAF8);
  static const Color backgroundDark = Color(0xFF111412);

  static const Color navBar = Color(0xFFEDF1EE);
  static const Color navBarDark = Color(0xFF1A1E1B);

  /// Matches flutter_native_splash.yaml — bridges the native splash and the
  /// real themed UI while AppSettingsCubit is still loading, so the swap to
  /// light/dark theme never flashes on top of already-rendered content.
  static const Color splashBackground = Color(0xFF42a5f5);

  static const primary = Color(0xFF0066FF);
  static const primaryDark = Color(0xFF0044AA);
  static const accent = Color(0xFFFF9800);
  static const tertiary = Color(0xFF000000);
  static const tertiaryDark = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF000000);
  static const tertiaryContainerDark = Color(0xFFFFFFFF);

  static const borderPrimary = Color(0xFF0066FF);
  static const borderSecondary = Color(0xFFFF9800);
  static const borderDisabled = Color(0xFFBDBDBD);

  static const textPrimary = Color(0xFF000000);
  static const textLight = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF757575);
  static const textSecondaryDark = Color(0xFF757575);
  static const textDisabled = Color(0xFFBDBDBD);

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  static const success = Color(0xFF4CAF50);
  static const error = Color(0xFFF44336);
  static const warning = Color(0xFFFFC107);
}
