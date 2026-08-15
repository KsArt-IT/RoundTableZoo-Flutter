import 'package:flutter/material.dart';
import 'package:roundtablezoo/core/theme/app_colors.dart';

abstract final class AppTextStyles {
  static TextStyle get display => const .new(
    color: AppColors.textPrimary,
    fontWeight: .w500,
    fontSize: 32,
    height: 1.0,
    letterSpacing: 0.0,
  );

  static TextStyle get headlineLarge => const .new(
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
    fontStyle: FontStyle.normal,
    fontWeight: .w400,
    fontSize: 20,
    height: 1.0,
    letterSpacing: -0.2,
  );

  static TextStyle get headlineMedium => const .new(
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
    fontStyle: FontStyle.normal,
    fontWeight: .w400,
    fontSize: 16,
    height: 1.0,
    letterSpacing: -0.2,
  );

  static TextStyle get headlineSmall => const .new(
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
    fontStyle: FontStyle.normal,
    fontWeight: .w400,
    fontSize: 12,
    height: 1.0,
    letterSpacing: -0.05,
  );

  static TextStyle get titleLarge => const .new(
    color: AppColors.textPrimary,
    fontWeight: .w500,
    fontSize: 24,
    height: 1.2,
    letterSpacing: -0.1,
  );

  static TextStyle get titleMedium => const .new(
    color: AppColors.textPrimary,
    fontWeight: .w500,
    fontSize: 18,
    height: 1.4,
    letterSpacing: 0.0,
  );

  static TextStyle get titleSmall => const .new(
    color: AppColors.textPrimary,
    fontWeight: .w300,
    fontSize: 14,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static TextStyle get bodyLarge => const .new(
    color: AppColors.textPrimary,
    fontWeight: .w400,
    fontSize: 18,
    height: 1.0,
    letterSpacing: 0.0,
  );

  static TextStyle get bodyMedium => const .new(
    color: AppColors.textPrimary,
    fontWeight: .w400,
    fontSize: 16,
    height: 1.0,
    letterSpacing: 0.0,
  );

  static TextStyle get bodySmall => const .new(
    color: AppColors.textPrimary,
    fontWeight: .w400,
    fontSize: 12,
    height: 1.0,
    letterSpacing: -0.2,
  );

  static TextStyle get label => const .new(
    color: AppColors.textPrimary,
    fontWeight: .w400,
    fontSize: 16,
    height: 1.0,
    letterSpacing: 0.0,
  );
}
