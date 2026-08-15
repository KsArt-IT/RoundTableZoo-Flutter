# Phase 1 — Data Model: Фундамент приложения

Источник требований — [spec.md](./spec.md) (FR-007…FR-017, FR-025a), решения — [research.md](./research.md).
Слои: `domain/entities/` — Freezed, без Drift; `data/datasources/drift/tables/` — схема;
`data/mappers/` — перевод между ними.

## Схема Drift

`schemaVersion = 1`, `MigrationStrategy` не пишется (конституция: до первого релиза схема меняется
поднятием версии). Внешние ключи включаются явно: `PRAGMA foreign_keys = ON` в
`beforeOpen` — иначе каскад из FR-011 не сработает.

### `day_entries` (`diary_tables.dart`)

| Колонка | Тип Drift | Ограничения | Заметки |
|---|---|---|---|
| `id` | `IntColumn` | PK, autoincrement | |
| `occurredAt` | `DateTimeColumn` | not null | Момент, к которому относится запись, **в UTC**. Дня в схеме нет — вычисляется (FR-009) |
| `moodScore` | `IntColumn` | not null, `check(moodScore >= 1 && moodScore <= 5)` | Явная эмодзи-шкала, не производная (FR-008) |
| `dayText` | `TextColumn` | nullable, `withLength(max: 2000)` | Только для будущих AI-реакций; на `moodScore` не влияет |
| `createdAt` | `DateTimeColumn` | not null | UTC, из `AppClock` |
| `updatedAt` | `DateTimeColumn` | not null | UTC, обновляется при перезаписи записи дня |

**Индекс**: `idx_day_entries_occurred_at` по `occurredAt` — все выборки дня и графика идут
диапазоном `[startUtc, endUtc)`. Уникального индекса по дню **нет** и быть не может (R2/R4).

### `character_reactions` (`diary_tables.dart`)

| Колонка | Тип Drift | Ограничения | Заметки |
|---|---|---|---|
| `id` | `IntColumn` | PK, autoincrement | |
| `dayEntryId` | `IntColumn` | not null, `references(DayEntries, #id, onDelete: KeyAction.cascade)` | FR-011 |
| `characterId` | `TextColumn` | not null | `'cat' \| 'dog' \| 'crocodile' \| 'hippo' \| …` — ссылка на статический конфиг, не таблица |
| `tone` | `TextColumn` | not null, default `'neutral'` | `ReactionTone.name`; неизвестное значение → `neutral` (FR-010b) |
| `reply` | `TextColumn` | not null | |
| `intensity` | `RealColumn` | not null, `check(intensity >= 0.0 && intensity <= 1.0)` | Амплитуда анимации |
| `isFallback` | `BoolColumn` | not null, default `false` | Заготовленная запасная реплика |
| `createdAt` | `DateTimeColumn` | not null | UTC |

**Индекс**: `idx_character_reactions_day_entry` по `dayEntryId`.

### `user_settings` (`app_tables.dart`)

Синглтон-таблица: ровно одна строка, `id = 1`.

| Колонка | Тип Drift | Значение по умолчанию | Заметки |
|---|---|---|---|
| `id` | `IntColumn` | PK, всегда `1` | `check(id = 1)` — вторая строка невозможна |
| `installId` | `TextColumn` | генерируется при вставке | 32 hex-символа, `Random.secure()` (FR-014, FR-015) |
| `themeMode` | `TextColumn` | `'system'` | `'light' \| 'dark' \| 'system'` |
| `locale` | `TextColumn` | `'system'` | `'ru' \| 'uk' \| 'en' \| 'system'` |
| `soundEnabled` | `BoolColumn` | `true` | |
| `enabledCharacterIds` | `TextColumn` | `["cat","dog","crocodile","hippo"]` | JSON-массив; минимум один включён |
| `hasSeenOnboarding` | `BoolColumn` | `false` | Хранится, вход не блокирует (FR-006) |
| `reminderEnabled` | `BoolColumn` | `false` | |
| `reminderTime` | `TextColumn` | `'20:00'` | `HH:mm`, применяется в фазе уведомлений |
| `dayStartHour` | `IntColumn` | `0` | `check(dayStartHour >= 0 && dayStartHour <= 23)` (FR-025a) |

## Domain-сущности

Все — Freezed, неизменяемые, без Drift/Flutter импортов.

### `DayEntry`

```
id: int?              // null до вставки
occurredAt: DateTime  // UTC
moodScore: MoodScore  // value object, 1..5
dayText: String?
createdAt: DateTime
updatedAt: DateTime
```

Дня среди полей **нет**. День получают вызовом `DayResolver.resolve(entry.occurredAt, …)` —
см. [contracts/app-clock.md](./contracts/app-clock.md).

### `CharacterReaction`

```
id: int?
dayEntryId: int
characterId: String
tone: ReactionTone
reply: String
intensity: double   // 0.0..1.0
isFallback: bool
createdAt: DateTime // UTC
```

### `UserSettings`

```
installId: String
themeMode: ThemePreference   // light | dark | system
locale: LocalePreference     // ru | uk | en | system
soundEnabled: bool
enabledCharacterIds: List<String>  // непустой
hasSeenOnboarding: bool
reminderEnabled: bool
reminderTime: ReminderTime   // часы+минуты
dayStartHour: DayStartHour   // 0..23
```

### `DayKey` (value object)

```
year: int, month: int, day: int
```

Результат вычисления дня. Сравнимый и сортируемый; используется как ключ группировки для будущего
графика и как «текущий день» в `CurrentDayCubit`. В БД не хранится.

## Value objects и правила валидации

| Тип | Правило | Нарушение |
|---|---|---|
| `MoodScore` | целое 1..5 | `ValidationFailure(code: moodScoreOutOfRange)` |
| `DayStartHour` | целое 0..23 | `ValidationFailure(code: dayStartHourOutOfRange)`; применяемым остаётся прежнее корректное значение (FR-025a) |
| `ReactionTone` | значение перечня `neutral \| warm \| playful \| dry \| sad \| encouraging` | неизвестное → `neutral`, реакция сохраняется (FR-010b) |
| `intensity` | double 0.0..1.0 | `ValidationFailure(code: intensityOutOfRange)` |
| `enabledCharacterIds` | непустой список | `ValidationFailure(code: noCharactersEnabled)` |
| `dayText` | ≤ 2000 символов, пустая строка нормализуется в `null` | `ValidationFailure(code: dayTextTooLong)` |
| `ReminderTime` | часы 0..23, минуты 0..59 | `ValidationFailure(code: reminderTimeInvalid)` |

Валидация живёт в `domain/value_objects/` (конструкторы-фабрики, возвращающие `Result<T>`), а не в
UI и не в мапперах — одно правило, одна точка.

## Правила жизненного цикла

**Создание хранилища (первый запуск)** — одна транзакция: создать строку `user_settings` с
значениями по умолчанию и свежесгенерированным `installId`. Записей дня нет (FR-013, FR-014,
US2 сценарий 1).

**Сохранение записи дня** (FR-009a) — транзакция:

1. `now = clock.nowUtc()`; `key = DayResolver.resolve(now, zone, dayStartHour)`.
2. `(startUtc, endUtc) = DayResolver.boundsUtc(key, zone, dayStartHour)`.
3. `SELECT … WHERE occurredAt >= startUtc AND occurredAt < endUtc ORDER BY occurredAt DESC LIMIT 1`.
4. Есть → `UPDATE` найденной записи (`moodScore`, `dayText`, `updatedAt = now`).
   Нет → `INSERT` (`occurredAt = createdAt = updatedAt = now`).

**Удаление записи дня** → каскадом удаляются все её реакции (FR-011). Реакция без записи дня
невозможна: `dayEntryId` not null + FK.

**Несколько записей в одном вычисленном дне** (FR-009b, FR-009c) — допустимое состояние после
смены пояса или `dayStartHour`. Ни слияния, ни удаления. Выборка значения дня для графика:
запись с максимальным `occurredAt` внутри границ дня; при равных `occurredAt` — с максимальным
`id` (FR-009d), то есть сортировка всегда `ORDER BY occurredAt DESC, id DESC`.

**`updatedAt`** меняется только при изменении `moodScore` или `dayText` (FR-007b). Добавление или
удаление реакции персонажа его не трогает.

**Смена `dayStartHour`** — меняется только строка настроек; `occurredAt` записей не трогается
(FR-026). Все дни пересчитываются при следующем чтении.

**Изменение схемы до релиза** — поднять `schemaVersion`, локальные данные разработки
сбрасываются (FR-017). После первого релиза правило меняется на обязательные миграции.

## Соответствие требованиям

| Требование | Где реализовано |
|---|---|
| FR-007, FR-008 | `day_entries` (`occurredAt` UTC, `moodScore` not null + check) |
| FR-009, FR-009a…c | Дня в схеме нет; `DayResolver` + транзакция сохранения; выборка «последняя в дне» |
| FR-010, FR-010a, FR-010b | `character_reactions.tone` + `ReactionTone` + маппер с подстановкой `neutral` |
| FR-011 | FK `onDelete: cascade` + `PRAGMA foreign_keys = ON` |
| FR-012, FR-013 | `user_settings` со значениями по умолчанию |
| FR-014, FR-015 | `installId`, генерация при вставке строки настроек |
| FR-016 | Хранилище локальное, сетевых datasource в фазе нет |
| FR-017 | `schemaVersion` без `MigrationStrategy` |
| FR-025, FR-025a | `dayStartHour` + `check(0..23)` + `DayStartHour` |
| FR-026 | Пересчёт при чтении; `occurredAt` неизменен |
