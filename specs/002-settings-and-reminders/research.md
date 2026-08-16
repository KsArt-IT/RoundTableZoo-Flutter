# Phase 0 — Research: Настройки и напоминания

Все решения проверены по исходникам установленных пакетов (`~/.pub-cache`, версии из
`app/pubspec.lock`) и по текущему коду `app/lib/`, а не по памяти. Где проверка была только по
README пакета (а не по коду), это указано явно.

---

## R1. Версия и API `flutter_local_notifications`

**Decision**: `flutter_local_notifications: ^22.3.0` (уже в `pubspec.yaml`, установлена 22.3.0).
Все вызовы — с **именованными** параметрами.

**Rationale**: начиная с v20 позиционные параметры `initialize()`, `show()`, `cancel()`,
`zonedSchedule()` заменены именованными (CHANGELOG 20.0.0). Проверенные сигнатуры из
`lib/src/flutter_local_notifications_plugin.dart`:

```dart
Future<bool?> initialize({
  required InitializationSettings settings,
  DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
});

Future<void> zonedSchedule({
  required int id,
  required TZDateTime scheduledDate,
  required NotificationDetails notificationDetails,
  required AndroidScheduleMode androidScheduleMode,   // обязателен, не имеет значения по умолчанию
  String? title,
  String? body,
  String? payload,
  DateTimeComponents? matchDateTimeComponents,
});

Future<void> cancel({required int id, String? tag});
Future<List<PendingNotificationRequest>> pendingNotificationRequests();
Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails();
```

**Alternatives considered**: примеры из интернета для v9–v17 (позиционные параметры,
`uiLocalNotificationDateInterpretation`) — не компилируются на 22.x. Не использовать.

---

## R2. Как выражается «ежедневное напоминание»: повтор или скользящее окно одноразовых

**Decision**: **скользящее окно одноразовых уведомлений** на `AppConstants.reminderHorizonDays`
(= 7) дней вперёд, по одному `zonedSchedule` на день, **без** `matchDateTimeComponents`.
Идентификатор детерминирован по дню: `id = year * 10000 + month * 100 + day` (для 2026-08-16 →
`20260816`, помещается в int32). Окно пересобирается на каждой точке согласования (R8).

**Rationale**: главный конфликт — FR-014a требует отменить **только сегодняшнее** напоминание,
когда настроение отмечено. При `matchDateTimeComponents: DateTimeComponents.time` уведомление
одно и повторяющееся: `cancel(id)` убивает **всю** серию, и восстановить «начиная с завтра»
нечем. Одноразовые уведомления с ключом по дню дают ровно ту гранулярность, которую требует
спека: отменяем `id` конкретного дня, остальные остаются.

Побочная выгода — FR-015 («не более одного за день») выполняется структурно: на день существует
ровно один возможный `id`, повторное планирование перезаписывает его, а не добавляет второе.

**Цена**: если пользователь не открывает приложение дольше горизонта, напоминания иссякают.
Приемлемо: 7 дней молчания — это уже отвал, а любое открытие приложения восстанавливает окно
целиком. Горизонт вынесен в константу, увеличить его — правка одного числа.

**Alternatives considered**:
- *Повторяющееся `DateTimeComponents.time`* — отвергнуто: несовместимо с FR-014a (см. выше).
- *Гибрид (повтор + одноразовая отмена на завтра)* — отвергнуто: требует восстанавливать серию
  после пропуска, состояние «серия жива/убита» нигде не хранится, поведение непроверяемо.
- *Горизонт 30+ дней* — отвергнуто: iOS жёстко ограничивает 64 ожидающими уведомлениями на
  приложение; 7 оставляет запас другим будущим уведомлениям (FR-025c).

---

## R3. Точность срабатывания и разрешение `SCHEDULE_EXACT_ALARM`

**Decision**: `AndroidScheduleMode.inexactAllowWhileIdle`. Разрешение `SCHEDULE_EXACT_ALARM` /
`USE_EXACT_ALARM` **не** запрашивается и в манифест **не** добавляется.

**Rationale**: FR-023 задаёт допуск «не более 60 минут позже, раньше — никогда»;
`inexactAllowWhileIdle` в это укладывается (типичное расхождение — минуты, в глубоком Doze —
до ближайшего окна обслуживания) и никогда не срабатывает раньше срока. Для напоминания
«отметь настроение» точность до секунды не нужна, а `USE_EXACT_ALARM` на Android 13+ подлежит
отдельному аудиту в Google Play (README пакета, раздел AndroidManifest.xml) — брать на себя это
ради допуска в пределах часа неразумно перед первой публикацией. `inexactAllowWhileIdle` при этом переживает
Doze, то есть не молчит на спящем устройстве (в отличие от `inexact`).

Это же снимает целый пользовательский путь: не нужен экран «разрешите точные будильники», не
нужен `canScheduleExactNotifications()`/`requestExactAlarmsPermission()`.

**Alternatives considered**: `exactAllowWhileIdle` + `SCHEDULE_EXACT_ALARM` — отвергнуто как
несоразмерное задаче и рискованное для ревью в Play. `inexact` — отвергнуто: не срабатывает в
Doze, то есть ровно ночью/вечером, когда телефон лежит без движения.

---

## R4. Разрешения на уведомления: чей API

**Decision**: использовать API самого `flutter_local_notifications`, **не** `permission_handler` и
**не** `app_settings`. Проверено в `lib/src/platform_flutter_local_notifications.dart`:

| Задача | Android | iOS |
|---|---|---|
| Запросить (FR-020) | `AndroidFlutterLocalNotificationsPlugin.requestNotificationsPermission()` | `IOSFlutterLocalNotificationsPlugin.requestPermissions(alert:badge:sound:)` |
| Проверить (FR-021, FR-022) | `areNotificationsEnabled()` | `checkPermissions()` → `NotificationsEnabledOptions` |
| Открыть системные настройки (FR-025b) | `openAppNotificationSettings()` | `openAppNotificationSettings()` |

**Rationale**: `openAppNotificationSettings()` появился именно в 22.3.0 (CHANGELOG) и есть на
обеих платформах — ровно то, что требует FR-025b, без второго пакета в этом пути. Принцип DRY из
`CLAUDE.md`: не заводить обёртку над `permission_handler`, когда уже подключённый пакет решает
задачу целиком и одинаково на двух платформах.

`permission_handler` и `app_settings` остаются в проекте для других нужд, но в коде напоминаний не
используются.

**Собственного диалога-предисловия нет** (FR-020a): включение тумблера уже выражает намерение,
поэтому `requestPermission()` вызывается непосредственно из обработчика тумблера. Различие
«ещё не спрашивали» / «отказано» (FR-022a) выводится так: на Android `areNotificationsEnabled()`
не различает эти состояния, поэтому приложение хранит **в памяти сессии** факт того, что запрос
уже делался в этом запуске, и трактует `false` до первого запроса как `unknown`, а после — как
`denied`. Персистить этот факт не нужно: при следующем запуске повторный системный запрос
безвреден — если система решит диалог не показывать, статус сразу вернётся `denied`, и
пользователь увидит предупреждение с переходом в системные настройки.

**Разовый тост при запуске** (FR-021b): проверка `permissionStatus()` выполняется на старте, если
`reminderEnabled == true`. Показ идёт через уже существующий `RootBlocListener` и
`FailureToastGate` — новой тост-инфраструктуры не заводим (DRY).

**Alternatives considered**: `permission_handler.Permission.notification` — отвергнуто: даёт тот же
результат, но добавляет второй источник истины о статусе разрешения и вторую платформенную
конфигурацию.

---

## R5. Восстановление расписания после перезагрузки (FR-024)

**Decision**: полагаемся на встроенный в пакет boot-ресивер; в `AndroidManifest.xml` приложения
добавляем:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
...
<receiver android:exported="false"
          android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
          android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```

Проверено: манифест самого пакета (`android/src/main/AndroidManifest.xml`) объявляет только
`POST_NOTIFICATIONS` и `VIBRATE` — с v16 всё остальное обязан объявить сам app. Текущий
`app/android/app/src/main/AndroidManifest.xml` не содержит ничего из перечисленного, то есть **без
этой правки FR-024 не выполняется вообще**.

На iOS отдельного действия не требуется: запланированные `UNNotificationRequest` переживают
перезагрузку силами системы.

**Проверено по README пакета, не по коду** — поведение ресивера подтверждается только на реальном
устройстве (см. `quickstart.md`, сценарий 6).

---

## R6. Deep-link по тапу (FR-017)

**Decision**: два пути, оба ведут в `AppRoutes.tablePath`:

1. **Приложение живо** — `onDidReceiveNotificationResponse` в `initialize()`; колбэк не трогает
   `BuildContext`, а кладёт `payload` в `NotificationLaunchQueue` (простой синглтон в
   `core/notifications/`), который читает `AppRoot`.
2. **Холодный старт** — `getNotificationAppLaunchDetails()` в `main.dart` **до** `runApp`;
   если `didNotificationLaunchApp == true`, начальный маршрут — `/table`.

`/table` и так `initialLocation` роутера (`app/router/app_router.dart`), поэтому холодный старт
уже соответствует FR-017 без единой строки. Реальная работа — только тёплый путь и только тогда,
когда открыт другой раздел.

**Rationale**: `payload` уведомления не должен содержать ничего чувствительного (принцип V) —
кладём константу `'reminder'`, а не дату и не текст.

**Alternatives considered**: фоновой изолят
(`onDidReceiveBackgroundNotificationResponse`) — не нужен: у уведомления нет actions, тап всегда
открывает UI. Отказ от него избавляет от `setPluginRegistrantCallback` в iOS-делегате.

**Показ на переднем плане (FR-016d)**: баннер обязан появляться и когда приложение открыто. На
Android это поведение по умолчанию для канала с достаточной важностью. На iOS — **нет**: без
зарегистрированного `UNUserNotificationCenter.delegate` уведомление на переднем плане молча
подавляется, поэтому регистрация делегата из R11 обязательна, а `DarwinNotificationDetails`
должен разрешать показ баннера и звука. Появление баннера при этом не меняет открытый раздел —
навигация только по тапу.

---

## R7. Локализованный текст уведомления без `BuildContext` (FR-016, FR-016a)

**Decision**: текст берётся из `AppLocalizations.delegate.load(locale)` (возвращает
`Future<AppLocalizations>` без дерева виджетов) в момент планирования. Локаль вычисляется из
`UserSettings.locale`; для `LocalePreference.system` переиспользуется существующий
`resolveDeviceLocale` из `core/utils/locale_resolution.dart` с
`PlatformDispatcher.instance.locale`.

**Rationale**: уведомление планируется заранее и срабатывает, когда приложения нет в памяти —
никакого `BuildContext` в этот момент не существует. Текст обязан быть «запечён» при планировании,
что ровно и означает FR-016 («язык, выбранный на момент планирования»). Переиспользование
`resolveDeviceLocale` — DRY: правило «неподдерживаемый язык → русский» уже реализовано там и не
должно появиться вторым экземпляром.

Ключи (нейтральные по FR-016a): `reminderNotificationTitle` («Звери за столом»),
`reminderNotificationBody` («Тебя ждут за круглым столом»). Формулировки в `intl_ru.arb` /
`intl_uk.arb` / `intl_en.arb`.

**Имя и описание канала (FR-016b)** — та же дисциплина и те же стоп-слова: строки
`notificationChannelName` / `notificationChannelDescription` видны в системных настройках, то есть
вне интерфейса приложения. Канал создаётся один раз при инициализации с **локалью, действующей на
тот момент**; система не переименовывает существующий канал при смене языка — это известное и
принятое ограничение, а не дефект (переименование потребовало бы пересоздавать канал и терять
пользовательские настройки звука по нему).

**Alternatives considered**: хранить готовый текст в БД — отвергнуто, лишнее состояние; смена
языка тогда требует миграции текстов. Пересобирать окно при смене языка — это и так происходит,
т.к. смена языка есть изменение `UserSettings` (R8).

---

## R8. Оркестрация: где живёт логика и когда пересобирается расписание

**Decision**: разделение на три части по границам конституции (принцип I):

| Слой | Класс | Ответственность | Зависимости |
|---|---|---|---|
| `domain/services/` | `ReminderPlanner` | **Чистая функция**: (сейчас, зона, `dayStartHour`, `reminderTime`, `enabled`, отмеченные дни) → список `ReminderOccurrence`. Ни Flutter, ни плагинов. | `DayResolver` |
| `core/notifications/` | `NotificationScheduler` (интерфейс) + `FlutterLocalNotificationScheduler` | Планирование/отмена/чтение очереди, разрешения. Единственное место, знающее про FLN. | FLN |
| `core/notifications/` | `ReminderCoordinator` | Согласование: взять настройки и отметки, спросить план у `ReminderPlanner`, привести очередь к плану. | `SettingsRepository`, `DiaryRepository`, `ReminderPlanner`, `NotificationScheduler`, `AppClock` |

`reconcile()` **идемпотентен**: вычисляет желаемое множество `(id, время)`, сравнивает с
`pendingNotificationRequests()`, отменяет лишние и планирует недостающие. Вызвать его дважды
подряд — no-op.

**Точки согласования** (FR-014b, FR-018, FR-025):

1. старт приложения (`main.dart`, после инициализации хранилища);
2. `AppLifecycleState.resumed` (`AppRoot._onResumed`, туда же, где уже обновляется часовой пояс);
3. любое изменение `UserSettings` — подписка на `SettingsRepository.watch()` внутри координатора
   (покрывает вкл/выкл, смену времени, смену `dayStartHour` и смену языка одним механизмом);
4. любое изменение `day_entries` — новый `DiaryRepository.watchEntriesChanged()`.

**Rationale по п.4**: FR-014a требует, чтобы отметка настроения гасила сегодняшнее напоминание.
Вешать это на «пусть экран „Стол“ не забудет позвать координатор» — хрупко: правило сломается
молча, когда экран будут писать в другой сессии. Drift и так умеет `watch()`; поток изменений
делает правило самоисполняющимся независимо от того, кто пишет в таблицу. Это единственное
добавление к `DiaryRepository` в этой фиче.

**Alternatives considered**:
- *Координатор как глобальный Cubit* — отвергнуто. Во-первых, у него нет состояния для UI. Во-
  вторых, `project/process/lessons-learned.md` фиксирует, что новый глобальный `@lazySingleton`
  Cubit, реально читаемый в дереве, ломает все widget-тесты на `buildTestAppRoot()` тремя разными
  способами. Не-Cubit-сервис этой цены не несёт.
- *Логика планирования внутри `SettingsCubit`* — отвергнуто: согласование нужно и когда экрана
  настроек нет на экране (старт, resume, отметка настроения).
- *Явный вызов из `saveTodayEntry`* — отвергнуто, см. выше.

---

## R9. Экран настроек: какой Cubit

**Decision**: `SettingsCubit` в `presentation/settings/cubit/`, регистрируется как `@injectable`
(factory, **не** `@lazySingleton`) и предоставляется маршрутом `/settings`. Читает
`SettingsRepository.watch()` и `NotificationScheduler` (статус разрешения). Глобальный
`AppSettingsCubit` **не трогаем и не расширяем** — он остаётся узким источником `themeMode`/
`locale` для `MaterialApp.router`.

**Rationale**: экранный Cubit не попадает в `AppRoot` и потому не воспроизводит грабли из
`lessons-learned.md`. Оба Cubit-а подписаны на один и тот же `watch()` — это не дублирование
состояния, а два потребителя одного потока (`AppMaterialRouter` использует `buildWhen` и на
изменение `reminderTime` не перестраивается).

**Статус разрешения** (FR-022) обновляется по возврату из системных настроек: `SettingsPage` —
`StatefulWidget` с `WidgetsBindingObserver`, на `resumed` зовёт `cubit.refreshPermissionStatus()`.
Экранный обсервер, а не глобальный: за пределами экрана настроек статус никого не интересует.

**Откат при ошибке сохранения** (FR-003) не требует отдельного механизма: UI рисуется по
`UserSettings` из `watch()`, а не по локальному состоянию переключателя. Неудачный `update*` не
меняет строку в БД → `watch()` не эмитит → элемент остаётся в прежнем положении сам собой, а
ошибка уходит тостом через `AppFailure`.

---

## R10. Что добавляется в `SettingsRepository`

**Decision**: два метода, по образцу существующих:

```dart
Future<Result<UserSettings>> updateReminderEnabled({required bool value});
Future<Result<UserSettings>> updateReminderTime(ReminderTime value);
```

**Rationale**: колонки `reminder_enabled` и `reminder_time` в `user_settings` **уже существуют**
(проверено в `app_database.g.dart`), сущность `UserSettings` уже несёт `reminderEnabled` и
`reminderTime`, `ReminderTime` уже валидирует и сериализуется в `HH:mm`. Изменение схемы БД не
требуется, `schemaVersion` не поднимается. Не хватает ровно пути записи.

---

## R11. Платформенная настройка

**Android** (`app/android/app/src/main/AndroidManifest.xml`) — см. R5. `POST_NOTIFICATIONS`
объявлен манифестом самого пакета, дублировать не нужно.

**Android**: канал уведомлений создаётся с важностью, достаточной для баннера на переднем плане и
для звука по умолчанию (FR-016c, FR-016d). Собственный звук не задаётся — канал берёт системный.

**iOS**:
- `DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false,
  requestSoundPermission: false)` — разрешение запрашивается явно при включении тумблера (FR-020),
  а не молча на старте.
- Регистрация `UNUserNotificationCenter.current().delegate` **обязательна**: без неё уведомление
  на переднем плане молча подавляется, а FR-016d этого не допускает. Приложение уже мигрировано на
  `UIScene` (`ios/Runner/SceneDelegate.swift` существует), поэтому регистрация идёт в
  `didInitializeImplicitFlutterEngine` в `AppDelegate.swift`, рядом с уже существующей
  регистрацией канала `backup_exclusion` — не в `didFinishLaunchingWithOptions`.
- `DarwinNotificationDetails` — с разрешённым показом баннера и звука, чтобы поведение на переднем
  плане совпадало с Android (FR-025a).
- `setPluginRegistrantCallback` **не нужен** (нет фоновых action-колбэков, см. R6).

**Проверено по README пакета, не по коду.** Обе платформенные правки проверяются только на
устройстве.

---

## R12. Тестируемость

**Decision**:

| Что | Как | Где |
|---|---|---|
| `ReminderPlanner` | Обычные unit-тесты, `FakeAppClock`, без моков | `test/domain/services/` |
| `ReminderCoordinator` | `mocktail` на `NotificationScheduler` + репозитории | `test/core/notifications/` |
| `SettingsCubit` | `bloc_test`, `mocktail` | `test/presentation/settings/` |
| Экран | widget-тесты на доступность и откат при ошибке | `test/widget/` |
| Реальная доставка | ручной прогон по `quickstart.md` на Android **и** iOS | — |

`NotificationScheduler` — абстрактный интерфейс именно ради этого: FLN невозможно осмысленно
подменить, платформенный канал в unit-тестах не отвечает.

**Граница проверяемого**: FR-024 (перезагрузка), FR-023 (Doze) и FR-025 (смена пояса) в
автотестах непроверяемы принципиально — они проверяются вручную. Автотесты покрывают то, что
`ReminderPlanner` выдаёт **правильные моменты**, включая случай «время напоминания раньше границы
суток» (FR-019a) и переход через границу.

**Widget-тесты**: любой новый тест на `buildTestAppRoot()` обязан последней строкой звать
`disposeTestAppRoot(tester)` (`lessons-learned.md`). Новых глобальных Cubit-ов фича не вводит, так
что описанная там тройка отказов не повторяется.

---

## Открытых вопросов нет

Все `NEEDS CLARIFICATION` из Technical Context разрешены выше. Пять уточнений из
`/speckit-clarify` (объём тумблеров персонажей, механизм подавления, нейтральность текста, паритет
платформ, взаимодействие с границей суток) уже зафиксированы в `spec.md` и здесь только
реализуются.
