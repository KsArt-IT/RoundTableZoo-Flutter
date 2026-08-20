# Contract — `DiaryRepository`: методы, добавляемые фазой 005

**Feature**: `005-diary-screen` | Файл: `app/lib/domain/repositories/diary_repository.dart`

Существующие методы (`saveTodayEntry`, `entryForDay`, `entriesForDay`, `entriesBetween`,
`deleteEntry`, `addReaction`, `reactionsFor`, `watchEntriesChanged`) **не меняются** — ни сигнатуры,
ни семантика. Ниже только три новых. Обоснование отступления от Assumptions спеки (которая
предполагала обойтись `entriesBetween`) — `research.md` R2/R3 и `plan.md` §Complexity Tracking.

Все методы возвращают `Result<T>` через `SafeCallMixin.safeCall` и не бросают исключений в
presentation (принцип II).

---

## 1. `entriesPage` — страница списка дней

```dart
/// Страница истории, новые дни первыми. Keyset-пагинация: [beforeOccurredAt]
/// — курсор из [DiaryPage.nextCursor] предыдущей страницы, `null` для
/// первой. Возвращает не более [limit] дней; если внутри дня несколько
/// записей, остаётся самая поздняя по `occurredAt` (FR-006, то же правило,
/// что у [entryForDay]).
Future<Result<DiaryPage>> entriesPage({
  DateTime? beforeOccurredAt,
  required int limit,
});
```

Возвращаемые типы — `domain/entities/` (data-model.md §2):

```dart
/// Запись дня вместе с вычисленным днём, к которому она отнесена.
/// `DayEntry` поля дня не имеет — он выводится `DayResolver` из
/// `occurredAt` + `dayStartHour`, а знание про `dayStartHour` не должно
/// покидать `data/` (принцип IV, research.md R15).
@freezed
abstract class DiaryDayEntry with _$DiaryDayEntry {
  const factory DiaryDayEntry({required DayKey day, required DayEntry entry}) = _DiaryDayEntry;
}

@freezed
abstract class DiaryPage with _$DiaryPage {
  const factory DiaryPage({
    required List<DiaryDayEntry> days,
    required bool hasMore,
    DateTime? nextCursor,
  }) = _DiaryPage;
}
```

| Аспект | Поведение |
|---|---|
| Порядок | `occurredAt DESC, id DESC`, дни от новых к старым |
| Курсор | строго `occurredAt < beforeOccurredAt` |
| Схлопывание дня | группировка через `DayResolver` + текущий `dayStartHour`; первая строка группы выигрывает |
| `hasMore` | `true`, когда datasource вернул ровно `limit` строк (значит, могут быть ещё). Вычисляется **в репозитории** — только он видит число строк до схлопывания |
| `nextCursor` | `DayResolver.boundsUtc(последний день страницы).startUtc` — **начало дня**, а не `occurredAt` последней записи |
| Пустая БД | `DiaryPage(days: [], hasMore: false, nextCursor: null)` |
| `limit <= 0` | `ValidationFailure` — программная ошибка вызывающего, не пользовательский сценарий |
| read-only режим | `UnavailableDiaryRepository` → `DatabaseFailure(code: storageReadOnly)` |

**Почему курсор — начало дня, а не `occurredAt` последней записи.** После смены таймзоны или
`dayStartHour` в одном дне может оказаться несколько записей (FR-009b фазы 001). Курсор по
`occurredAt` самой поздней из них оставил бы более ранние записи **того же дня** за границей
страницы — следующий запрос вернул бы их, и в списке появился бы второй раз тот же день с другим
`id`, что нарушает и FR-004b, и FR-006. Дедупликация на стороне `DiaryCubit` этого не ловит: `id`
у строк разные. Курсор по началу дня исключает день целиком.

Прогресс гарантирован и в вырожденном случае: даже если весь `limit` строк пришёлся на один день,
страница вернёт один день, а `nextCursor` встанет на его начало — следующий запрос уйдёт строго
раньше.

Новый метод datasource (`data/datasources/diary_local_datasource.dart`):

```dart
Future<List<DayEntryRow>> entriesBefore(DateTime? beforeUtc, int limit);
```

Использует существующий индекс `idx_day_entries_occurred_at`.

---

## 2. `moodHistory` — полный ряд точек графика

```dart
/// Вся история как точки графика, по возрастанию дня, одна точка на день
/// (FR-006, FR-010). Проекция только `occurredAt`+`moodScore` — `dayText`
/// не читается (research.md R3).
Future<Result<List<MoodChartPoint>>> moodHistory();
```

| Аспект | Поведение |
|---|---|
| Порядок | `day` по возрастанию (график читается слева направо) |
| Дни без записи | **отсутствуют** в списке; разрыв рисует виджет (FR-012) |
| Источник значения | исключительно `day_entries.moodScore`; `character_reactions` не участвует (FR-011, SC-007) |
| Пустая БД | `Result.success(const [])` |
| read-only режим | `DatabaseFailure(code: storageReadOnly)` |

Новый метод datasource:

```dart
/// Проекция (occurredAt, moodScore) по всей таблице, `occurredAt DESC`.
Future<List<({DateTime occurredAt, int moodScore})>> moodProjection();
```

---

## 3. `reactionsForEntries` — реплики пачкой

```dart
/// Реплики для нескольких записей одним запросом. Ключ — `dayEntryId`;
/// записи без реплик в карте отсутствуют. Внутри значения — порядок
/// `createdAt ASC`, включая повторные ответы одного персонажа (FR-015).
Future<Result<Map<int, List<CharacterReaction>>>> reactionsForEntries(
  List<int> dayEntryIds,
);
```

| Аспект | Поведение |
|---|---|
| Назначение | CSV-экспорт (FR-023, SC-005) — снимает N+1 из `reactionsFor` на день |
| Пустой вход | `Result.success(const {})`, без обращения к БД |
| Соотношение с `reactionsFor` | `reactionsFor(id)` остаётся: одиночное раскрытие дня (FR-014) и восстановление реплик на Столе. Разные формы возврата и разные вызывающие; общий SQL-предикат живёт в datasource |
| read-only режим | `DatabaseFailure(code: storageReadOnly)` |

Новый метод datasource:

```dart
Future<List<CharacterReactionRow>> reactionsForEntryIds(List<int> ids);
```

---

## 4. `UnavailableDiaryRepository` (MOD)

`data/repositories/read_only_repositories.dart` реализует три новых метода тем же
`DatabaseFailure(null, code: DatabaseFailure.storageReadOnly)`, что и остальные, — это то, что
`DiaryCubit` превращает в состояние `unavailable` (FR-029, research.md R13).
