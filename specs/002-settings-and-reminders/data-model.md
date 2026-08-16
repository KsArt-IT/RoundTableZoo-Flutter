# Phase 1 — Модель данных: Настройки и напоминания

**Схема БД не меняется.** `schemaVersion` не поднимается, миграция не пишется. Всё, что фича
хранит, уже лежит в таблице `user_settings` — не хватало только пути записи (research.md, R10).

---

## Существующее, что фича использует

### `UserSettings` (`domain/entities/user_settings.dart`) — без изменений

| Поле | Тип | Роль в этой фиче |
|---|---|---|
| `themeMode` | `ThemePreference` | FR-005…FR-007 |
| `locale` | `LocalePreference` | FR-008…FR-011, язык текста уведомления (FR-016) |
| `soundEnabled` | `bool` | FR-026 |
| `reminderEnabled` | `bool` | FR-012 |
| `reminderTime` | `ReminderTime` | FR-013 |
| `dayStartHour` | `DayStartHour` | FR-019, FR-019a — граница суток для подавления |
| `installId` | `String` | не используется |
| `enabledCharacterIds` | `List<String>` | **вне объёма** (Clarifications, Q1) |
| `hasSeenOnboarding` | `bool` | не используется |

Значения по умолчанию (заданы в `001-app-foundation`): системная тема, системный язык, звук
включён, `reminderEnabled = false`, `reminderTime = 20:00`.

### Value objects — без изменений

- `ReminderTime` — `hour`/`minute`, валидация `0..23` / `0..59` через `create()` →
  `Result<ReminderTime>` с `ValidationFailure.reminderTimeInvalid`; хранение как `HH:mm`;
  `fromStorage` при мусоре откатывается к `defaultValue` (20:00), а не роняет чтение.
- `ThemePreference`, `LocalePreference`, `DayStartHour`, `DayKey` — используются как есть.

---

## Новое в `domain/`

### `ReminderOccurrence` (`domain/entities/reminder_occurrence.dart`)

Одно запланированное срабатывание. Не персистится — вычисляется заново на каждом согласовании.

| Поле | Тип | Смысл |
|---|---|---|
| `day` | `DayKey` | День (по `dayStartHour`), к которому относится напоминание — **не** календарная дата срабатывания (FR-019a) |
| `scheduledAtUtc` | `DateTime` | Момент срабатывания в UTC |

```dart
/// Идентификатор уведомления в системной очереди. Детерминирован по дню,
/// чтобы отмена била ровно в нужное срабатывание (FR-014a) и чтобы
/// повторное планирование перезаписывало, а не добавляло второе (FR-015).
/// 2026-08-16 → 20260816; помещается в int32 до 2147 года.
int get notificationId => day.year * 10000 + day.month * 100 + day.day;
```

**Инварианты**

- `scheduledAtUtc` строго в будущем относительно момента планирования — прошедшие срабатывания в
  план не попадают (edge case «время сегодня уже прошло»).
- `day` всегда получен из `scheduledAtUtc` через `DayResolver.resolve` — это и есть механизм
  FR-019a: если напоминание в 02:00 при `dayStartHour = 4`, `day` окажется вчерашним ключом, и
  подавление сработает по нему.
- Двух `ReminderOccurrence` с одинаковым `day` в одном плане быть не может.

### `ReminderPlanner` (`domain/services/reminder_planner.dart`)

Чистая функция, без Flutter и без `DateTime.now()` (принцип IV).

```dart
List<ReminderOccurrence> plan({
  required DateTime nowUtc,
  required tz.Location zone,
  required UserSettings settings,
  required Set<DayKey> recordedDays,
  int horizonDays = AppConstants.reminderHorizonDays,
});
```

**Правила**

1. `settings.reminderEnabled == false` → пустой список (FR-012, FR-018).
2. Иначе перебираются ближайшие `horizonDays` срабатываний по стенным часам
   `settings.reminderTime` в `zone`, начиная с первого строго после `nowUtc`.
3. Для каждого срабатывания `day = DayResolver.resolve(момент, zone, settings.dayStartHour)`.
4. Срабатывание отбрасывается, если `recordedDays.contains(day)` (FR-014, FR-014a).
5. При совпадении `day` у двух срабатываний остаётся раннее (возможно при `dayStartHour`,
   сдвигающем сутки, и при переходах DST).

**Почему `Set<DayKey>`, а не «отмечен ли сегодня»**: план строится на неделю вперёд, и любой из
этих дней уже может быть отмечен — например, после смены `dayStartHour`. Множество делает функцию
чистой и полностью проверяемой без обращения к БД.

---

## Новое в контрактах репозиториев

### `SettingsRepository` (+2 метода)

```dart
Future<Result<UserSettings>> updateReminderEnabled({required bool value});
Future<Result<UserSettings>> updateReminderTime(ReminderTime value);
```

Гарантии те же, что у существующих `update*`: возвращают полное новое состояние, `watch()` эмитит
после успеха. Валидация `ReminderTime` происходит до вызова (в `ReminderTime.create`), поэтому
репозиторий получает уже корректное значение.

### `DiaryRepository` (+1 метод)

```dart
/// Эмитит при любом изменении `day_entries`. Единственный потребитель —
/// `ReminderCoordinator`: отметка настроения обязана гасить сегодняшнее
/// напоминание независимо от того, какой экран её записал (FR-014a).
Stream<void> watchEntriesChanged();
```

Обоснование отдельным потоком, а не явным вызовом из «Стола» — research.md, R8.

---

## Состояние, живущее вне приложения

### Статус разрешения на уведомления

Не сущность и не хранимое поле — читается у системы на каждом запросе (research.md, R4).

| Значение | Что означает | Что показывает экран |
|---|---|---|
| `granted` | Уведомления придут | Обычный вид тумблера |
| `denied` | Отказано, повторный системный запрос может не появиться | Предупреждение + действие «Открыть настройки» (FR-021, FR-025b) |
| `unknown` | Ещё не спрашивали | Обычный вид; запрос будет при включении (FR-020) |

### Системная очередь уведомлений

Источник истины о том, что реально запланировано, — `pendingNotificationRequests()`. Приложение
своей копии расписания **не хранит**: дубликат состояния разошёлся бы с системой после
перезагрузки, отзыва разрешения или очистки данных. Согласование всегда сравнивает план с
фактической очередью (research.md, R8).
