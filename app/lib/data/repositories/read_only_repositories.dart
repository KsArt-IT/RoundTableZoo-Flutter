import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/utils/install_id_generator.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_entry.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';

const _storageReadOnly = Result<Never>.failure(
  DatabaseFailure(null, code: DatabaseFailure.storageReadOnly),
);

/// Stands in for [SettingsRepository] while `StorageMode.readOnly` — the
/// shell stays usable, but nothing is persisted (FR-021d).
///
/// `installId` is generated fresh for this session only: never read from
/// (there's nothing to read) and never written to disk (FR-021d1, FR-021d2).
class ReadOnlySettingsRepository implements SettingsRepository {
  ReadOnlySettingsRepository() : _sessionSettings = _defaults(generateInstallId());

  final UserSettings _sessionSettings;

  static UserSettings _defaults(String installId) => UserSettings(
    installId: installId,
    themeMode: ThemePreference.system,
    locale: LocalePreference.system,
    soundEnabled: true,
    enabledCharacterIds: const ['cat', 'dog', 'crocodile', 'hippo'],
    hasSeenOnboarding: false,
    reminderEnabled: false,
    reminderTime: ReminderTime.defaultValue,
    dayStartHour: DayStartHour.defaultValue,
  );

  @override
  Future<Result<UserSettings>> load() async => Result.success(_sessionSettings);

  @override
  Stream<UserSettings> watch() => Stream.value(_sessionSettings);

  @override
  Future<Result<UserSettings>> updateThemeMode(ThemePreference value) async => _storageReadOnly;

  @override
  Future<Result<UserSettings>> updateLocale(LocalePreference value) async => _storageReadOnly;

  @override
  Future<Result<UserSettings>> updateDayStartHour(DayStartHour value) async => _storageReadOnly;

  @override
  Future<Result<UserSettings>> updateSoundEnabled({required bool value}) async => _storageReadOnly;

  @override
  Future<Result<UserSettings>> updateEnabledCharacters(List<String> characterIds) async =>
      _storageReadOnly;

  @override
  Future<Result<UserSettings>> markOnboardingSeen() async => _storageReadOnly;
}

/// Stands in for [DiaryRepository] while `StorageMode.readOnly` — reads
/// come back empty rather than exposing stale/inaccessible data; writes
/// fail explicitly instead of silently doing nothing (FR-021d).
class UnavailableDiaryRepository implements DiaryRepository {
  const UnavailableDiaryRepository();

  @override
  Future<Result<DayEntry>> saveTodayEntry({required MoodScore moodScore, String? dayText}) async =>
      _storageReadOnly;

  @override
  Future<Result<DayEntry?>> entryForDay(DayKey key) async => const Result.success(null);

  @override
  Future<Result<List<DayEntry>>> entriesForDay(DayKey key) async => const Result.success([]);

  @override
  Future<Result<List<DayEntry>>> entriesBetween(DayKey from, DayKey to) async =>
      const Result.success([]);

  @override
  Future<Result<void>> deleteEntry(int id) async => _storageReadOnly;

  @override
  Future<Result<CharacterReaction>> addReaction(CharacterReaction reaction) async =>
      _storageReadOnly;

  @override
  Future<Result<List<CharacterReaction>>> reactionsFor(int dayEntryId) async =>
      const Result.success([]);
}
