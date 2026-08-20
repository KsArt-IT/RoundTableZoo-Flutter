# Phase 1 — Data Model: Экран «Дневник»

**Feature**: `005-diary-screen` | **Date**: 2026-08-19

Дневник — **читатель**, а не писатель (FR-027). Новых таблиц, колонок и миграций нет; ниже —
что берётся как есть, что добавляется в `domain/`, и как устроено состояние экрана.

---

## 1. Существующие сущности (используются без изменений)

| Тип | Файл | Что берёт Дневник |
|---|---|---|
| `DayEntry` | `domain/entities/day_entry.dart` | `id`, `occurredAt`, `moodScore`, `dayText` |
| `CharacterReaction` | `domain/entities/character_reaction.dart` | `characterId`, `reply`, `isFallback`, `createdAt` |
| `DayKey` | `domain/entities/day_key.dart` | день записи; `toString()` → `yyyy-MM-dd` для CSV (FR-022) |
| `MoodScore` | `domain/value_objects/mood_score.dart` | значение 1..5 |
| `Character` | `domain/entities/character.dart` | `name`, `colorHex` для подписи реплики (FR-016) |
| `MoodScale` | `core/constants/mood_scale.dart` | эмодзи/цвет/локализованная подпись (FR-001) |

Таблицы `day_entries` / `character_reactions` (`data/datasources/drift/tables/diary_tables.dart`)
не меняются; `schemaVersion` не поднимается.

---

## 2. Новые доменные сущности

### `MoodChartPoint` — `domain/entities/mood_chart_point.dart` (NEW)

```dart
@freezed
abstract class MoodChartPoint with _$MoodChartPoint {
  const factory MoodChartPoint({
    required DayKey day,
    required MoodScore moodScore,
  }) = _MoodChartPoint;
}
```

- Ряд отсортирован по возрастанию `day`; ровно одна точка на день (R15).
- Дни без записи в ряду **отсутствуют** — разрыв вычисляется на стороне графика (FR-012), а не
  кодируется псевдо-значением.
- Не дубликат `DayEntry`: у `DayEntry` нет поля дня вообще, у `MoodChartPoint` нет `dayText`,
  `id` и временных меток (проверка DRY из `CLAUDE.md`, research.md R4).

### `DiaryDayEntry` — `domain/entities/diary_day_entry.dart` (NEW)

```dart
@freezed
abstract class DiaryDayEntry with _$DiaryDayEntry {
  const factory DiaryDayEntry({
    required DayKey day,
    required DayEntry entry,
  }) = _DiaryDayEntry;
}
```

Запись дня вместе с днём, к которому её отнёс `DayResolver`. Существует потому, что у `DayEntry`
поля дня нет **принципиально** (день выводится из `occurredAt` + `dayStartHour`), а знание про
`dayStartHour` не должно покидать `data/` (принцип IV, research.md R15). Без этого типа и список, и
CSV вынуждены были бы вычислять день сами.

### `DiaryPage` — `domain/entities/diary_page.dart` (NEW)

```dart
@freezed
abstract class DiaryPage with _$DiaryPage {
  const factory DiaryPage({
    required List<DiaryDayEntry> days,
    required bool hasMore,
    DateTime? nextCursor,
  }) = _DiaryPage;
}
```

Результат одной страницы: сами дни, признак «есть ли что-то старее» (FR-004c) и курсор для
следующего запроса. `hasMore` и `nextCursor` вычисляет репозиторий — только он видит число
строк до схлопывания и границы дня (contracts/diary-repository.md §1).

---

---

## 3. Модели уровня реализации (не доменные)

### `DiaryDay` — `presentation/diary/cubit/diary_state.dart`

Одна карточка списка: запись дня + всё, что нужно её отрисовать.

```dart
@freezed
abstract class DiaryDay with _$DiaryDay {
  const factory DiaryDay({
    required DiaryDayEntry record,           // день + запись, как их отдал репозиторий
    @Default(false) bool expanded,          // FR-014: одно раскрытие на карточку —
                                            // и полный текст дня, и реплики (R7)
    @Default(false) bool reactionsLoading,
    List<CharacterReaction>? reactions,      // null = ещё не загружали (R7)
  }) = _DiaryDay;

  const DiaryDay._();

  DayKey get day => record.day;

  DayEntry get entry => record.entry;

  /// Force unwrap обоснован: `DiaryDay` строится только из строк, пришедших
  /// из БД, а `DayEntry.id` равен `null` лишь до первой записи (конституция
  /// §VI требует такого обоснования в коде, не только в ревью).
  int get entryId => record.entry.id!;
}
```

- `reactions == null` → реплики ни разу не запрашивали; `reactions == []` → запрашивали, их нет
  (FR-018 показывает «реплик не было» именно во втором случае, не в первом).
- `record` хранится целиком, а не расщепляется на `day` + `entry` рядом друг с другом — пара
  «день + запись» уже выражена типом `DiaryDayEntry`, и раскладывать её ещё раз плоско запрещает
  правило «одна причина существования — один тип» из `CLAUDE.md`. `day`/`entry` доступны геттерами.
- Флаг `expanded` один на карточку: свёрнутая карточка обрезает длинный текст дня, раскрытая
  показывает и текст целиком, и блок реплик (research.md R7). Второго состояния «текст раскрыт» нет.

### `CsvRow` — `domain/usecases/export_diary_to_csv.dart`

Не отдельный публичный тип: строка CSV формируется прямо при обходе (`date`, `moodScore`,
`dayText`, `characterId`, `characterReply`) — заводить сущность ради пяти строковых полей,
существующих доли секунды, противоречит бритве Оккама. Контракт формата — в
[contracts/csv-export.md](./contracts/csv-export.md).

---

## 4. Состояние экрана — `DiaryState`

`presentation/diary/cubit/diary_state.dart`, Freezed sealed (принцип II).

```dart
@freezed
sealed class DiaryState with _$DiaryState {
  const factory DiaryState.initial() = DiaryInitial;
  const factory DiaryState.loading() = DiaryLoading;              // FR-008
  const factory DiaryState.loaded(DiaryData data) = DiaryLoaded;
  const factory DiaryState.unavailable() = DiaryUnavailable;      // FR-029, R13
  const factory DiaryState.error(AppFailure failure) = DiaryError; // FR-008a
}

@freezed
abstract class DiaryData with _$DiaryData {
  const factory DiaryData({
    required List<DiaryDay> days,              // новые первыми (FR-001)
    required List<MoodChartPoint> chart,       // вся история (FR-010)
    required Map<String, Character> characters,// caption реплик (FR-016, R8)
    required bool hasMore,                     // FR-004c
    @Default(false) bool loadingMore,          // FR-004a
    @Default(false) bool exporting,            // блокирует повторный тап
    AppFailure? pageFailure,                   // сбой догрузки страницы (R19, CHK006)
  }) = _DiaryData;

  const DiaryData._();

  bool get isEmpty => days.isEmpty;            // FR-007
  bool get canExport => days.isNotEmpty && !exporting; // FR-024
}
```

### Переходы

```text
initial ──load()──► loading ──успех──► loaded
                        │
                        ├── storageReadOnly ──► unavailable
                        └── прочий AppFailure ─► error ──retry()──► loading

loaded ──loadMore()────► loaded(loadingMore: true) ──► loaded(days += page, hasMore: …)
loaded ──toggleDay(id)─► loaded(day.expanded ^= true) [+ разовая догрузка реплик]
loaded ──watchEntriesChanged──► loaded(первая страница и chart перечитаны, R12)
loaded ──export()──────► loaded(exporting: true) ──► loaded(exporting: false) [+ ShareService]
```

Инварианты:

- `days` не содержит двух элементов с одинаковым `entryId` (FR-004b) — при слиянии страницы
  фильтр по уже присутствующим `entryId`.
- Параллельные вызовы `loadMore()` не складываются: пока `loadingMore == true`, повторный вызов —
  no-op (FR-004b).
- `hasMore == false` ⟺ последний запрос страницы вернул меньше строк, чем `limit` (R2, R15).
- Ни `days`, ни `chart` никогда не выводятся из `CharacterReaction.tone`/`intensity` (FR-011,
  SC-007) — эти поля вообще не читаются нигде, кроме отображения самой реплики.
- Переход в `unavailable`/`error` не затирает уже показанные `days` частично: состояние заменяется
  целиком, чтобы экран не смешивал «часть истории» с баннером ошибки. Это правило про **первую**
  загрузку (FR-008a); сбой догрузки следующей страницы остаётся в `loaded` через `pageFailure`
  (research.md R19).

---

## 5. Новые константы — `core/constants/app_constants.dart` (MOD)

| Константа | Значение | Требование |
|---|---|---|
| `diaryPageSize` | `30` | FR-004, SC-008 |
| `diaryExportBatchSize` | `200` | SC-005, R11 |
| `diaryRefreshDebounce` | `Duration(milliseconds: 300)` | FR-009, R12 |
| `diaryChartDailyMaxDays` | `90` | FR-010a, R5 |
| `diaryChartWeeklyMaxDays` | `731` | FR-010a, R5 |
| `diaryChartMaxScale` | `12.0` | FR-010b, R6 |
| `diaryChartInitialDays` | `30` | начальный видимый диапазон графика, R18 |
| `diaryChartMinValue` / `diaryChartMaxValue` | `1.0` / `5.0` | фиксированная ось значений, R18, SC-007 |
| `diaryPrefetchThreshold` | `diaryPageSize ~/ 2` | порог старта подгрузки, R19 |
