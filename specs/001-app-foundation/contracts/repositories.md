# Контракт: domain-репозитории

`domain/repositories/` — `abstract interface class`, только Dart. Все методы возвращают
`Result<T>`; исключения наружу не выходят (принцип II, FR-018). Реализации в
`data/repositories/` оборачивают работу в `SafeCallMixin.safeCall`.

## `SettingsRepository`

```dart
abstract interface class SettingsRepository {
  /// Текущие настройки. При первом запуске строка создаётся со значениями
  /// по умолчанию и свежим installId — вызывающий об этом не знает.
  Future<Result<UserSettings>> load();

  /// Реактивный поток настроек (Drift watch). Источник для AppSettingsCubit.
  Stream<UserSettings> watch();

  Future<Result<UserSettings>> updateThemeMode(ThemePreference value);
  Future<Result<UserSettings>> updateLocale(LocalePreference value);
  Future<Result<UserSettings>> updateDayStartHour(DayStartHour value);
  Future<Result<UserSettings>> updateSoundEnabled({required bool value});
  Future<Result<UserSettings>> updateEnabledCharacters(List<String> characterIds);
  Future<Result<UserSettings>> markOnboardingSeen();
}
```

**Гарантии**

- `load()` идемпотентен: повторные вызовы не создают вторую строку и не меняют `installId`
  (FR-014, US2.5).
- Любой `update*` возвращает **новое полное состояние** настроек — вызывающему не нужно
  перечитывать.
- `watch()` эмитит после каждого успешного изменения; это единственный механизм мгновенного
  применения темы и языка (FR-027, SC-006).

## `DiaryRepository`

```dart
abstract interface class DiaryRepository {
  /// Создаёт запись за текущий вычисленный день или обновляет существующую.
  /// Правило «не более одной записи на день» проверяется здесь, в транзакции.
  Future<Result<DayEntry>> saveTodayEntry({
    required MoodScore moodScore,
    String? dayText,
  });

  /// Запись, относящаяся к указанному дню; при нескольких — самая поздняя
  /// по occurredAt (FR-009c).
  Future<Result<DayEntry?>> entryForDay(DayKey key);

  /// Все записи, попавшие в указанный день, от поздних к ранним.
  /// Обычно одна; больше одной — после смены пояса или dayStartHour (FR-009b).
  Future<Result<List<DayEntry>>> entriesForDay(DayKey key);

  /// Записи в диапазоне дней — основа будущего графика.
  Future<Result<List<DayEntry>>> entriesBetween(DayKey from, DayKey to);

  /// Удаляет запись и каскадом все её реакции (FR-011).
  Future<Result<void>> deleteEntry(int id);

  Future<Result<CharacterReaction>> addReaction(CharacterReaction reaction);
  Future<Result<List<CharacterReaction>>> reactionsFor(int dayEntryId);
}
```

**Гарантии**

- `saveTodayEntry` атомарен: два параллельных вызова не создают две записи за один день (FR-009a,
  SC-008).
- `entryForDay` при нескольких записях в дне возвращает запись с максимальным `occurredAt`, при
  равных моментах — с максимальным `id` (FR-009d). То же правило действует для графика (SC-012).
- `addReaction` с тоном вне перечня сохраняет реакцию с `ReactionTone.neutral`, не отклоняя её
  (FR-010b, SC-015).
- `deleteEntry` для несуществующего id — `DatabaseFailure(code: entityNotFound)`, не исключение.

## Коды ошибок

Используются существующие подклассы `AppFailure` (`core/errors/app_failure.dart`); локализованный
текст берётся только из `localizedMessage`, не собирается в UI (принцип II).

| Подкласс | Код | Когда |
|---|---|---|
| `DatabaseFailure` | `entityNotFound` | Запрошенной записи нет |
| `DatabaseFailure` | `savingError` | Сбой записи (в т.ч. нет места на устройстве) |
| `DatabaseFailure` | `storageUnavailable` (**новый**) | Файл БД не открывается при запуске (FR-021a) |
| `DatabaseFailure` | `storageReadOnly` (**новый**) | Попытка записи в режиме «без сохранения» (FR-021d) |
| `ValidationFailure` | `moodScoreOutOfRange`, `dayStartHourOutOfRange`, `intensityOutOfRange`, `noCharactersEnabled`, `dayTextTooLong`, `reminderTimeInvalid` | Нарушены правила из [data-model.md](../data-model.md) |
| `InitializationFailure` | — | Сбой последовательности запуска вне БД |

Каждый новый код обязан иметь строку в `intl_ru.arb` (и заготовки в `uk`/`en`) и ветку в
`localizedMessage` соответствующего подкласса (FR-020).

## Реализации для режима «без сохранения»

`data/repositories/read_only_repositories.dart` — регистрируются в DI вместо обычных, когда
`StorageMode.readOnly` (FR-021d, FR-021e):

| Класс | Чтение | Запись |
|---|---|---|
| `ReadOnlySettingsRepository` | настройки по умолчанию (без `installId` из БД — генерируется на сессию, не сохраняется) | `DatabaseFailure(code: storageReadOnly)` |
| `UnavailableDiaryRepository` | пустой список / `null` | `DatabaseFailure(code: storageReadOnly)` |

Оболочка при этом режиме показывает постоянный баннер и кнопку повторной попытки; молчаливого
удаления данных не происходит ни в одном пути (FR-021a).
