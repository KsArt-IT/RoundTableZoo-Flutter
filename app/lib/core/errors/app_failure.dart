import 'dart:async';

import 'package:flutter/services.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// Base exception class for the application
sealed class AppFailure implements Exception {
  factory AppFailure.fromError(Object error) => switch (error) {
    AppFailure() => error,

    PlatformException(
      :final code,
      :final message,
    ) =>
      PlatformFailure(
        message ?? error.toString(),
        code,
      ),

    TimeoutException(:final message) => TimeoutFailure(message),

    FormatException(:final message) => SerializationFailure(message),

    _ => UnknownFailure(error.toString()),
  };

  const AppFailure(this.message, [this.code]);

  final String message;
  final String? code;

  String localizedMessage(AppLocalizations locale) {
    return message;
  }

  @override
  String toString() => 'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Unknown error
class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message, [super.code]);
}

/// Platform related exceptions
class PlatformFailure extends AppFailure {
  const PlatformFailure(super.message, [super.code]);
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure(String? message, {String? code}) : super(message ?? '', code);
}

class SerializationFailure extends AppFailure {
  const SerializationFailure(super.message, [super.code]);
}

/// Initialization related exceptions
class InitializationFailure extends AppFailure {
  const InitializationFailure(super.message, [super.code]);
}

/// Network related exceptions
class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, [super.code]);
}

/// Validation related exceptions
class ValidationFailure extends AppFailure {
  const ValidationFailure(String? message, {String? code}) : super(message ?? '', code);

  static const moodScoreOutOfRange = 'mood_score_out_of_range';
  static const dayStartHourOutOfRange = 'day_start_hour_out_of_range';
  static const intensityOutOfRange = 'intensity_out_of_range';
  static const noCharactersEnabled = 'no_characters_enabled';
  static const dayTextTooLong = 'day_text_too_long';
  static const reminderTimeInvalid = 'reminder_time_invalid';

  /// `TableCubit.requestReaction` precondition (FR-014): no mood picked
  /// yet. Same wording as the always-visible on-screen hint (FR-014a) —
  /// this signal is defense in depth, not a separate message.
  static const moodNotSelected = 'mood_not_selected';

  /// `TableCubit.requestReaction` precondition (FR-014): day text blank.
  static const dayTextEmpty = 'day_text_empty';

  @override
  String localizedMessage(AppLocalizations locale) => switch (code) {
    moodScoreOutOfRange => locale.moodScoreOutOfRange,
    dayStartHourOutOfRange => locale.dayStartHourOutOfRange,
    intensityOutOfRange => locale.intensityOutOfRange,
    noCharactersEnabled => locale.noCharactersEnabled,
    dayTextTooLong => locale.dayTextTooLong,
    reminderTimeInvalid => locale.reminderTimeInvalid,
    moodNotSelected => locale.tableNeedMoodHint,
    dayTextEmpty => locale.tableNeedTextHint,
    _ => message,
  };
}

/// Settings related exceptions
class SettingsFailure extends AppFailure {
  const SettingsFailure(super.message, [super.code]);
}

/// Database related exceptions
class DatabaseFailure extends AppFailure {
  const DatabaseFailure(String? message, {String? code}) : super(message ?? '', code);

  static const uniqueViolation = 'unique_violation';
  static const entityNotFound = 'entity_not_found';
  static const savingError = 'saving_error';
  static const storageUnavailable = 'storage_unavailable';
  static const storageReadOnly = 'storage_read_only';

  @override
  String localizedMessage(AppLocalizations locale) => switch (code) {
    uniqueViolation => locale.uniqueViolation,
    entityNotFound => locale.entityNotFound,
    savingError => locale.savingError,
    storageUnavailable => locale.storageUnavailable,
    storageReadOnly => locale.storageReadOnly,
    _ => message,
  };
}

/// ai-proxy related exceptions — codes match the taxonomy in
/// `specs/004-table-screen/contracts/ai-proxy-client.md` §4. HTTP status →
/// code mapping happens only in `AiReactionRepositoryImpl` (principle I/II);
/// `TableCubit` sees just these codes.
class AiProxyFailure extends AppFailure {
  const AiProxyFailure(String? message, {String? code}) : super(message ?? '', code);

  static const network = 'network';
  static const rateLimited = 'rate_limited';
  static const aiDisabled = 'ai_disabled';
  static const invalidResponse = 'invalid_response';
  static const timeout = 'timeout';

  @override
  String localizedMessage(AppLocalizations locale) => switch (code) {
    network => locale.tableAiNetworkError,
    rateLimited => locale.tableAiRateLimitedError,
    aiDisabled => locale.tableAiDisabledError,
    timeout || invalidResponse => locale.tableAiInvalidResponseError,
    _ => message,
  };
}

/// Notification related exceptions
class NotificationFailure extends AppFailure {
  const NotificationFailure(String? message, {String? code}) : super(message ?? '', code);

  static const notFound = 'not_found';
  static const notLaunch = 'not_launch_details';

  @override
  String localizedMessage(AppLocalizations locale) => switch (code) {
    notFound => locale.notificationNotFound,
    _ => locale.notificationFailure(message),
  };
}
