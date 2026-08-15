import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';

/// Standalone validation rules for entity fields that stay plain Dart types
/// (`double`, `String?`, `List<String>`) rather than dedicated value
/// objects — see data-model.md.
abstract final class Validators {
  const Validators._();

  /// `CharacterReaction.intensity`: animation amplitude, 0.0..1.0.
  static Result<double> intensity(double value) {
    if (value < 0.0 || value > 1.0) {
      return const Result.failure(
        ValidationFailure(null, code: ValidationFailure.intensityOutOfRange),
      );
    }
    return Result.success(value);
  }

  /// `DayEntry.dayText`: at most [AppConstants.maxDayTextLength] characters;
  /// an empty string normalizes to `null` rather than failing.
  static Result<String?> dayText(String? value) {
    final normalized = (value == null || value.isEmpty) ? null : value;
    if (normalized != null && normalized.length > AppConstants.maxDayTextLength) {
      return const Result.failure(
        ValidationFailure(null, code: ValidationFailure.dayTextTooLong),
      );
    }
    return Result.success(normalized);
  }

  /// `UserSettings.enabledCharacterIds`: must not be empty.
  static Result<List<String>> enabledCharacterIds(List<String> value) {
    if (value.isEmpty) {
      return const Result.failure(
        ValidationFailure(null, code: ValidationFailure.noCharactersEnabled),
      );
    }
    return Result.success(value);
  }
}
