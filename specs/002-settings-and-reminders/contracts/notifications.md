# Контракт: сервис уведомлений и согласование расписания

`core/notifications/` — единственное место в приложении, знающее про
`flutter_local_notifications`. Ни `domain/`, ни `presentation/` его не импортируют.

---

## `NotificationScheduler` (порт)

```dart
/// Абстракция над системной очередью уведомлений. Реализация —
/// `FlutterLocalNotificationScheduler`; в тестах подменяется mocktail-моком
/// (платформенный канал в unit-тестах не отвечает).
abstract interface class NotificationScheduler {
  /// Инициализация плагина и колбэка тапа. Идемпотентна.
  Future<Result<void>> initialize();

  /// Текущий статус разрешения (data-model.md).
  Future<NotificationPermissionStatus> permissionStatus();

  /// Системный запрос разрешения (FR-020). Возвращает статус ПОСЛЕ ответа
  /// пользователя. Если система решила диалог не показывать, возвращается
  /// `denied` — вызывающий не отличает «отказал сейчас» от «отказал
  /// раньше», и не должен: реакция одна (FR-021).
  Future<NotificationPermissionStatus> requestPermission();

  /// Открывает системные настройки уведомлений приложения (FR-021,
  /// FR-025b). Работает одинаково на Android и iOS.
  Future<Result<void>> openSystemSettings();

  /// Что реально стоит в очереди — источник истины (data-model.md).
  Future<Result<Set<int>>> pendingIds();

  Future<Result<void>> schedule(ReminderOccurrence occurrence, {
    required String title,
    required String body,
  });

  Future<Result<void>> cancel(int notificationId);
}
```

**Гарантии реализации**

- Все методы возвращают `Result<T>` через `SafeCallMixin.safeCall`; наружу исключений не летит
  (принцип II).
- `schedule` планирует **одноразовое** уведомление на `occurrence.scheduledAtUtc`, приведённое к
  `tz.TZDateTime` в зоне из `AppClock.location`. `matchDateTimeComponents` не передаётся
  (research.md, R2).
- `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle` — всегда (research.md, R3).
  Допуск доставки — не более 60 минут позже заданного времени, раньше — никогда (FR-023).
- `payload` уведомления — константа `'reminder'`. Ни даты, ни текста дня, ни `installId`
  (принцип V).
- Звук и вибрация — умолчания канала; собственный звук не задаётся (FR-016c).
- Показ на переднем плане включён на обеих платформах (FR-016d): на iOS это требует
  зарегистрированного `UNUserNotificationCenter.delegate`, иначе баннер молча подавляется
  (research.md, R11).
- `initialize()` до первого `schedule` обязателен; повторный вызов — no-op. Он же создаёт канал
  уведомлений с нейтральными именем и описанием (FR-016b).

---

## `ReminderCoordinator` (оркестрация)

```dart
/// Приводит системную очередь в соответствие с настройками и отметками.
/// Не Cubit: у него нет состояния для UI, а глобальный Cubit сломал бы
/// widget-тесты (project/process/lessons-learned.md).
class ReminderCoordinator {
  /// Подписывается на `SettingsRepository.watch()` и
  /// `DiaryRepository.watchEntriesChanged()`; каждая эмиссия ведёт к
  /// `reconcile()`.
  ReminderCoordinator({ ... });

  /// Идемпотентно. Считает план `ReminderPlanner.plan(...)`, сравнивает с
  /// `pendingIds()`, отменяет лишнее, планирует недостающее.
  Future<Result<void>> reconcile();

  Future<void> dispose();
}
```

**Алгоритм `reconcile()`**

1. `settings = await settingsRepository.load()`; при ошибке — выход с `Result.failure`, очередь не
   трогаем (лучше устаревшее расписание, чем стёртое).
2. Если `permissionStatus() != granted` → отменить всё своё и выйти. Планировать без разрешения
   бессмысленно и создаёт ложное впечатление в `pendingIds()`.
3. `recordedDays` — дни с записями в горизонте, из `DiaryRepository.entriesBetween`.
4. `plan = reminderPlanner.plan(nowUtc: clock.nowUtc(), zone: clock.location, settings, recordedDays)`.
   Из плана следует и восстановление напоминания после удаления записи дня (FR-014c), и пересчёт
   принадлежности дней после смены `dayStartHour` (FR-019c) — обе ситуации приходят как обычная
   эмиссия наблюдаемого потока и не требуют отдельных веток.
5. `desired = {occurrence.notificationId}`; `pending = await scheduler.pendingIds()`.
6. Отменить `pending − desired`, **ограничившись своим диапазоном id** (см. ниже).
7. Запланировать `desired − pending` (и перепланировать те, чьё время изменилось: при смене
   `reminderTime` id остаётся прежним, поэтому шаг 7 всегда переписывает весь `desired` — это
   дешевле, чем хранить времена, и перезапись по тому же id безопасна).

**Диапазон id**: `reconcile` владеет только идентификаторами вида `YYYYMMDD` (research.md, R2).
Чужие id из очереди не удаляются — будущие уведомления другой природы не должны страдать.

**Точки вызова** (FR-014b, FR-025):

| Когда | Кто зовёт |
|---|---|
| Старт приложения | `main.dart`, после того как хранилище признано пригодным. Там же — разовая проверка статуса разрешения при `reminderEnabled == true` и тост через `RootBlocListener`, если разрешения нет (FR-021b) |
| `AppLifecycleState.resumed` | `AppRoot._onResumed` — после `AppClock.updateLocation`, чтобы новый пояс уже действовал (FR-025) |
| Изменение `UserSettings` | подписка внутри координатора |
| Изменение `day_entries` | подписка внутри координатора (FR-014a) |
| Смена дня | не нужна отдельно: `AppClock` не пишет в БД, а окно на 7 дней переживает ролловер до ближайшего resume |

**Порядок на resume критичен**: сначала `AppClock.updateLocation`, потом `reconcile()`. Иначе план
будет посчитан в старом часовом поясе — ровно тот отказ, который FR-025 запрещает.

---

## Текст уведомления

```dart
/// Локализованные строки уведомления без BuildContext (research.md, R7).
Future<({String title, String body})> reminderTexts(LocalePreference preference);
```

- Локаль: `preference.toLocale()`, для `system` — `resolveDeviceLocale(PlatformDispatcher.instance.locale, AppLocalizations.supportedLocales)`.
- Строки: `reminderNotificationTitle`, `reminderNotificationBody`, а также
  `notificationChannelName` и `notificationChannelDescription` — в трёх `.arb`.
- **Запрет (FR-016a, FR-016b, SC-006a)**: ни в одном языке ни одна из этих четырёх строк не
  содержит понятий «настроение», «эмоции», «чувства», «самочувствие», «дневник» и их переводов.
  Проверяется тестом, который читает сгенерированные строки и падает на стоп-словах, — иначе
  правило умрёт при первой же правке копирайта. Тест покрывает **и строки канала**: они видны в
  системных настройках, то есть вне интерфейса приложения.
- **Известное ограничение**: имя канала фиксируется при его создании; система не переименовывает
  существующий канал при смене языка приложения. Пересоздание канала стёрло бы пользовательские
  настройки звука по нему, поэтому язык имени канала остаётся тем, что действовал при первом
  запуске. На нейтральность (FR-016b) это не влияет — строка нейтральна на любом языке.
