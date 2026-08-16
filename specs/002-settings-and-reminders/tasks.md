---

description: "Task list for 002-settings-and-reminders"
---

# Tasks: Настройки — тема, язык, напоминания

**Input**: Design documents from `/specs/002-settings-and-reminders/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/)

**Tests**: Тестовые задачи включены — этого требует конституция проекта (принцип VI: `bloc_test`
на каждый новый Cubit, покрытие >70%, моки `mocktail`), а не отдельная просьба.

**Organization**: Задачи сгруппированы по историям из `spec.md`, чтобы каждую можно было
реализовать и проверить отдельно.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: можно выполнять параллельно (разные файлы, нет незакрытых зависимостей)
- **[Story]**: к какой истории относится задача (US1…US5)
- Пути указаны от корня репозитория; код приложения живёт в `app/`

## Path Conventions

Проект — одно Flutter-приложение в `app/`. Раскладка «слои, не фичи»: `app/lib/domain/`,
`app/lib/data/`, `app/lib/core/`, `app/lib/presentation/<экран>/`, тесты — `app/test/`.

**Кодогенерация**: после правки `@freezed` / `@injectable` / Drift-таблиц обязателен
`cd app && dart run build_runner build --delete-conflicting-outputs`. После правки `.arb` —
`flutter gen-l10n`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: константы и платформенная обвязка. Новых пакетов не добавляется — всё уже в
`app/pubspec.yaml`.

- [X] T001 [P] Добавить `reminderHorizonDays = 7` и `reminderDeliveryTolerance = Duration(minutes: 60)` в `app/lib/core/constants/app_constants.dart` (FR-015a, FR-023, FR-025c)
- [X] T002 [P] Добавить в `app/android/app/src/main/AndroidManifest.xml` разрешение `RECEIVE_BOOT_COMPLETED` и ресиверы `ScheduledNotificationReceiver` + `ScheduledNotificationBootReceiver` с intent-filter по образцу research.md R5 (FR-024). `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` НЕ добавлять (research.md R3)
- [X] T003 [P] Зарегистрировать `UNUserNotificationCenter.current().delegate` в `didInitializeImplicitFlutterEngine` в `app/ios/Runner/AppDelegate.swift`, рядом с существующей регистрацией канала `backup_exclusion` (FR-016d, research.md R11)

**Checkpoint**: платформа готова принимать запланированные уведомления и показывать их на переднем плане

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: каркас экрана настроек, общий для US1, US2 и US5. Без него ни одна история не
демонстрируема.

**⚠️ CRITICAL**: до завершения этой фазы работа по историям не начинается

- [X] T004 [P] Создать перечисление `NotificationPermissionStatus` (`granted` / `denied` / `unknown`) в `app/lib/core/notifications/notification_permission_status.dart` (FR-022a, data-model.md). **Идёт первым** — T005 использует этот тип
- [X] T005 Создать `SettingsState` (Freezed sealed: `loading` / `loaded(UserSettings settings, NotificationPermissionStatus permission)` / `error(AppFailure failure)`) в `app/lib/presentation/settings/cubit/settings_state.dart` (зависит от T004, contracts/ui-contracts.md)
- [X] T006 Создать `SettingsCubit` в `app/lib/presentation/settings/cubit/settings_cubit.dart`: подписка на `SettingsRepository.watch()`, эмиссия `loaded`/`error`, отмена подписки в `close()`. Пока сервис уведомлений не существует, в `permission` кладётся `NotificationPermissionStatus.unknown` (contracts/ui-contracts.md). Сеттеры добавляются в фазах историй
- [X] T007 Зарегистрировать `SettingsCubit` как `@injectable` **factory** (не `@lazySingleton`) — экранный, не глобальный, чтобы не повторить грабли из `project/process/lessons-learned.md`
- [X] T008 Создать `SettingsPage` (`StatefulWidget` с `WidgetsBindingObserver`) в `app/lib/presentation/settings/settings_page.dart`: `BlocProvider` с `getIt<SettingsCubit>()`, каркас всех секций в окончательной разметке, в состоянии `loading` элементы управления недоступны и разметка не сдвигается при переходе в `loaded` (FR-004)
- [X] T009 Заменить `SettingsPlaceholderPage` на `SettingsPage` в `app/lib/app/router/app_router.dart` и удалить `app/lib/presentation/settings/settings_placeholder_page.dart` (FR-001, contracts/ui-contracts.md). Кнопки «Сохранить» на экране нет ни в одной секции — каждый сеттер пишет сразу (FR-002)
- [X] T010 [P] Добавить ключи секций (`settingsAppearance`, `settingsLanguage`, `settingsReminder`, `settingsSound`) в `app/lib/l10n/intl_ru.arb`, затем в `intl_uk.arb` и `intl_en.arb`
- [X] T011 Запустить `dart run build_runner build --delete-conflicting-outputs` и `flutter gen-l10n`; убедиться, что `app/lib/gen/untranslated_messages.json` пуст

**Checkpoint**: `/settings` открывает реальный экран с секциями; управление появится в фазах историй

---

## Phase 3: User Story 1 — Тема оформления (Priority: P1) 🎯 MVP

**Goal**: пользователь выбирает светлую / тёмную / системную тему, интерфейс перекрашивается сразу
и выбор переживает перезапуск.

**Independent Test**: открыть «Настройки», выбрать тёмную тему → все три раздела темнеют немедленно;
перезапустить приложение → первый кадр уже тёмный.

### Tests for User Story 1

- [X] T012 [P] [US1] `bloc_test` на `setThemeMode`: успех, ошибка репозитория, `isClosed` после `await` — в `app/test/presentation/settings/settings_cubit_test.dart`

### Implementation for User Story 1

- [X] T013 [US1] Добавить `setThemeMode(ThemePreference)` в `app/lib/presentation/settings/cubit/settings_cubit.dart` — вызов `SettingsRepository.updateThemeMode` (метод уже существует), ошибка уходит в состояние `error` (FR-005, FR-006)
- [X] T014 [US1] Создать секцию выбора темы в `app/lib/presentation/settings/widgets/theme_section.dart`: три варианта, выбранный помечен не только цветом, тап-таргет ≥ `AppConstants.minTapTargetDp`, `Semantics(label:)` с текущим значением (FR-005, FR-027, FR-028, FR-028a)
- [X] T015 [P] [US1] Добавить ключи `settingsThemeLight`, `settingsThemeDark`, `settingsThemeSystem` в три `.arb`
- [X] T016 [US1] Widget-тест на секцию темы в `app/test/widget/settings_page_test.dart`: элемент возвращается в прежнее положение при неудачном сохранении (FR-003), доступность (FR-027), **и семантика системной темы** — при `ThemePreference.system` смена темы устройства меняет оформление, при явных `light`/`dark` не меняет (FR-007, US1.2, US1.3). Если тест использует `buildTestAppRoot()` — последней строкой `disposeTestAppRoot(tester)` (`lessons-learned.md`)

**Checkpoint**: US1 полностью работает и демонстрируема отдельно

---

## Phase 4: User Story 2 — Язык интерфейса (Priority: P1)

**Goal**: пользователь выбирает язык из поддерживаемых или системный; весь интерфейс, включая
тексты ошибок, переключается немедленно.

**Independent Test**: переключить язык на английский → подписи разделов, экран настроек и текст
ошибки на английском без перезапуска.

### Tests for User Story 2

- [X] T017 [P] [US2] `bloc_test` на `setLocale`: успех, ошибка, сохранение варианта `system` — в `app/test/presentation/settings/settings_cubit_test.dart`

### Implementation for User Story 2

- [X] T018 [US2] Добавить `setLocale(LocalePreference)` в `app/lib/presentation/settings/cubit/settings_cubit.dart` — вызов существующего `SettingsRepository.updateLocale` (FR-008, FR-009)
- [X] T019 [US2] Создать секцию выбора языка в `app/lib/presentation/settings/widgets/language_section.dart`: названия языков написаны на самих этих языках и не переводятся (FR-011); вариант «системный» остаётся отмеченным даже при неподдерживаемом языке устройства (FR-010)
- [X] T020 [P] [US2] Добавить ключ `settingsLanguageSystem` в три `.arb`; названия языков задать константами, а не переводимыми строками (FR-011)
- [X] T021 [US2] Widget-тест в `app/test/widget/settings_page_test.dart`: при `LocalePreference.system` и неподдерживаемом языке устройства вариант «системный» отмечен, интерфейс на русском (FR-010)

**Checkpoint**: US1 и US2 работают независимо друг от друга

---

## Phase 5: User Story 3 — Включение напоминания и его время (Priority: P2)

**Goal**: пользователь включает напоминание и задаёт время; уведомление приходит, если день не
отмечен, и открывает «Стол» по тапу.

**Independent Test**: включить напоминание на время через 2–3 минуты, свернуть приложение,
дождаться уведомления, тапнуть → открылся «Стол».

### Domain (чистый Dart, без Flutter)

- [X] T022 [P] [US3] Создать `ReminderOccurrence` (`DayKey day`, `DateTime scheduledAtUtc`, геттер `notificationId = year*10000 + month*100 + day`) в `app/lib/domain/entities/reminder_occurrence.dart` (data-model.md)
- [X] T023 [US3] Создать `ReminderPlanner.plan({nowUtc, zone, settings, recordedDays, horizonDays})` в `app/lib/domain/services/reminder_planner.dart`: перебор ближайших срабатываний по стенным часам, `DayKey` через существующий `DayResolver`, отбрасывание отмеченных дней и прошедших моментов, пустой список при выключенном напоминании (FR-012, FR-014, FR-015, FR-015a, FR-019a, FR-019b)
- [X] T024 [P] [US3] Unit-тесты `ReminderPlanner` в `app/test/domain/services/reminder_planner_test.dart` c `FakeAppClock`: обычный случай, выключенное напоминание, отмеченный день, время сегодня уже прошло, **время раньше границы суток** (FR-019a), **время ровно на границе** (FR-019b), горизонт = 7 (FR-015a)

### Repositories

- [X] T025 [US3] Добавить `updateReminderEnabled({required bool value})` и `updateReminderTime(ReminderTime value)` в `app/lib/domain/repositories/settings_repository.dart` (contracts/repositories.md)
- [X] T026 [US3] Добавить `Stream<void> watchEntriesChanged()` в `app/lib/domain/repositories/diary_repository.dart` (FR-014a, contracts/repositories.md)
- [X] T027 [US3] Реализовать оба сеттера в `app/lib/data/repositories/settings_repository_impl.dart` через существующий приватный `_update(UserSettingsTableCompanion(...))`; колонки `reminder_enabled`/`reminder_time` уже есть, схему БД не менять
- [X] T028 [US3] Реализовать наблюдение `day_entries` в `app/lib/data/datasources/diary_local_datasource.dart` и `watchEntriesChanged()` в `app/lib/data/repositories/diary_repository_impl.dart`
- [X] T029 [US3] Добавить три новых метода в `app/lib/data/repositories/read_only_repositories.dart`: сеттеры возвращают `DatabaseFailure.storageReadOnly`, `watchEntriesChanged()` — пустой поток (FR-024a). **Без этого проект не скомпилируется**

### Core: сервис уведомлений

- [X] T030 [P] [US3] Создать порт `NotificationScheduler` (интерфейс из contracts/notifications.md) в `app/lib/core/notifications/notification_scheduler.dart`
- [X] T031 [US3] Реализовать `FlutterLocalNotificationScheduler` в `app/lib/core/notifications/flutter_local_notification_scheduler.dart` — единственный файл, импортирующий `flutter_local_notifications`. Именованные параметры (v22 API), `AndroidScheduleMode.inexactAllowWhileIdle`, без `matchDateTimeComponents`, `payload: 'reminder'`, звук и вибрация — умолчания канала, показ на переднем плане разрешён (FR-016c, FR-016d, FR-023, research.md R1–R3)
- [X] T032 [US3] Создать канал уведомлений внутри `initialize()` в `app/lib/core/notifications/flutter_local_notification_scheduler.dart` — имя и описание из l10n, нейтральные; важность достаточна для баннера и звука (FR-016b, FR-016c, FR-016d)
- [X] T033 [P] [US3] Создать `reminderTexts(LocalePreference)` в `app/lib/core/notifications/reminder_texts.dart` — `AppLocalizations.delegate.load(locale)` без `BuildContext`, для `system` переиспользовать существующий `resolveDeviceLocale` из `core/utils/locale_resolution.dart` (FR-016, research.md R7)
- [X] T034 [P] [US3] Добавить ключи `reminderNotificationTitle`, `reminderNotificationBody`, `notificationChannelName`, `notificationChannelDescription` в три `.arb` — нейтральные формулировки без запрещённых понятий (FR-016a, FR-016b)
- [X] T035 [P] [US3] Тест на стоп-слова в `app/test/core/notifications/reminder_texts_test.dart`: ни одна из четырёх строк ни на одном языке не содержит понятий из FR-016a (FR-016b, SC-006a)
- [X] T036 [US3] Создать `NotificationLaunchQueue` в `app/lib/core/notifications/notification_launch_queue.dart` — приём `payload` из `onDidReceiveNotificationResponse` без обращения к `BuildContext` (FR-017, research.md R6)
- [X] T037 [US3] Создать `ReminderCoordinator` в `app/lib/core/notifications/reminder_coordinator.dart`: идемпотентный `reconcile()` по алгоритму из contracts/notifications.md, подписки на `SettingsRepository.watch()` и `DiaryRepository.watchEntriesChanged()`, `dispose()` с отменой подписок. Отменять только свои id вида `YYYYMMDD` (FR-014a, FR-014b, FR-014c, FR-018, FR-019c, FR-025c)
- [X] T038 [US3] Зарегистрировать `NotificationScheduler` и `ReminderCoordinator` в `app/lib/core/di/injection_module.dart` (ленивая резолюция репозиториев — как у существующих `currentDayCubit`/`appSettingsCubit`)
- [X] T039 [P] [US3] Тесты `ReminderCoordinator` в `app/test/core/notifications/reminder_coordinator_test.dart` c `mocktail`: идемпотентность повторного `reconcile()`, отмена сегодняшнего при отметке дня и планирование завтрашнего (FR-014a), восстановление после удаления записи (FR-014c), чужие id в очереди не трогаются, перепланирование при смене времени (FR-018)

### Wiring

- [X] T040 [US3] В `app/lib/main.dart`: `NotificationScheduler.initialize()`, чтение `getNotificationAppLaunchDetails()` до `runApp`, первый `ReminderCoordinator.reconcile()` после того как хранилище признано пригодным (FR-014b, FR-017)
- [X] T041 [US3] В `app/lib/app/app_root.dart` в `_onResumed()` вызвать `reconcile()` **после** `AppClock.updateLocation` — порядок критичен, иначе план считается в старом поясе (FR-014b, FR-025)

### UI

- [X] T042 [US3] Добавить `setReminderEnabled({required bool value})` и `setReminderTime(ReminderTime)` в `app/lib/presentation/settings/cubit/settings_cubit.dart` (FR-012, FR-013)
- [X] T043 [US3] Создать секцию напоминания в `app/lib/presentation/settings/widgets/reminder_section.dart`: тумблер, выбор времени (активен только при включённом напоминании, формат 12/24 ч по локали), `Semantics` озвучивает время как время (FR-012, FR-013, FR-013a, FR-028a)
- [X] T044 [P] [US3] Добавить ключи `settingsReminderEnabled`, `settingsReminderTime` в три `.arb`
- [X] T045 [P] [US3] `bloc_test` на `setReminderEnabled` и `setReminderTime` в `app/test/presentation/settings/settings_cubit_test.dart`, включая проверку значений по умолчанию на свежей установке: напоминание выключено, время 20:00 (FR-012a)

**Checkpoint**: напоминание приходит и открывает «Стол»; отказ в разрешении ещё не обработан

---

## Phase 6: User Story 4 — Разрешения, перезагрузка, часовой пояс (Priority: P2)

**Goal**: напоминание не отказывает молча — отказ в разрешении виден и исправим, расписание
переживает перезагрузку и смену часового пояса.

**Independent Test**: отказать в разрешении → на экране предупреждение и кнопка в системные
настройки; выдать разрешение и вернуться → предупреждение исчезло без повторного щелчка тумблером.

### Tests for User Story 4

- [X] T046 [P] [US4] `bloc_test` в `app/test/presentation/settings/settings_cubit_test.dart`: включение при `granted`, при `denied` (системный запрос не повторяется), `refreshPermissionStatus()` после возврата из системных настроек (FR-020, FR-022, FR-022a)
- [X] T047 [P] [US4] Тесты `ReminderPlanner` на время в `app/test/domain/services/reminder_planner_test.dart`: несуществующий час при переходе на летнее время → ближайший следующий существующий; удвоенный час → ровно одно срабатывание; смена зоны не сдвигает время (FR-025, FR-025d). **Тестируют код из T023 (US3)** — если US3 выпускается отдельно, эти тесты стоит написать вместе с T024
- [X] T048 [P] [US4] Тест `ReminderCoordinator` в `app/test/core/notifications/reminder_coordinator_test.dart`: при `permission != granted` очередь очищается и ничего не планируется

### Implementation for User Story 4

- [X] T049 [US4] Реализовать `permissionStatus()`, `requestPermission()`, `openSystemSettings()` в `app/lib/core/notifications/flutter_local_notification_scheduler.dart` через API самого FLN (`requestNotificationsPermission` / `areNotificationsEnabled` / `requestPermissions` / `checkPermissions` / `openAppNotificationSettings`) — без `permission_handler` и `app_settings` (FR-020, FR-021, FR-025b, research.md R4)
- [X] T050 [US4] Реализовать различение `unknown` / `denied`: факт того, что запрос уже делался, хранится в памяти сессии; `false` до первого запроса — `unknown`, после — `denied` (FR-022a, research.md R4)
- [X] T051 [US4] Вызывать `requestPermission()` прямо из обработчика тумблера, без собственного диалога-предисловия; настройка сохраняется независимо от ответа (FR-020, FR-020a, contracts/ui-contracts.md)
- [X] T052 [US4] Добавить в `app/lib/presentation/settings/widgets/reminder_section.dart` предупреждение при `denied` **и** включённом напоминании, с действием «Открыть настройки» (FR-021, FR-021a, FR-025b)
- [X] T053 [US4] Реализовать `refreshPermissionStatus()` в `SettingsCubit` и вызов из `didChangeAppLifecycleState(resumed)` в `app/lib/presentation/settings/settings_page.dart` — экранный обсервер, не глобальный (FR-022)
- [X] T054 [US4] Реализовать разовый тост при запуске: в `app/lib/main.dart` вычислить флаг `remindersMuted` (напоминание включено И статус ≠ `granted`) и передать его в `AppRoot`; в `app/lib/app/app_root.dart` показать тост один раз в `addPostFrameCallback` внутри маршрутизированного дерева. **Не** через `RootBlocListener`/`FailureToastGate` — это не ошибка, а гейт схлопывает повторы окном 3 с, а не на запуск (FR-021b, contracts/ui-contracts.md)
- [X] T054a [US4] Widget-тест в `app/test/widget/app_root_toast_test.dart`: при `remindersMuted: true` тост показан ровно один раз и не появляется повторно после `pump()` и смены раздела; завершать тест `disposeTestAppRoot(tester)` (FR-021b)
- [X] T055 [P] [US4] Добавить ключи `settingsReminderPermissionDenied`, `settingsOpenSystemSettings`, `reminderPermissionRevokedToast` в три `.arb`
- [X] T056 [US4] Заблокировать включение напоминания в режиме read-only: обработать `DatabaseFailure.storageReadOnly` в `app/lib/presentation/settings/cubit/settings_cubit.dart` и показать ту же ошибку, что при прочих сбоях записи; убедиться, что `ReminderCoordinator` при этом ничего не планирует (FR-024a)

**Checkpoint**: ни один отказ не проходит молча; US3 и US4 вместе дают напоминание, пригодное к релизу

---

## Phase 7: User Story 5 — Звук озвучки (Priority: P3)

**Goal**: пользователь включает и выключает озвучку реплик персонажей; на уведомления это не влияет.

**Independent Test**: переключить звук, вернуться на экран позже → положение сохранилось.

- [X] T057 [P] [US5] `bloc_test` на `setSoundEnabled` в `app/test/presentation/settings/settings_cubit_test.dart`
- [X] T058 [US5] Добавить `setSoundEnabled({required bool value})` в `app/lib/presentation/settings/cubit/settings_cubit.dart` — вызов существующего `SettingsRepository.updateSoundEnabled` (FR-026)
- [X] T059 [US5] Создать секцию звука в `app/lib/presentation/settings/widgets/sound_section.dart`; подпись должна давать понять, что настройка не касается уведомлений (FR-016c, FR-026)
- [X] T060 [P] [US5] Добавить ключ `settingsSoundHint` в три `.arb` (FR-016c)

**Checkpoint**: все пять историй работают независимо

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T061 [P] Сплошной проход по доступности `app/lib/presentation/settings/`: тап-таргеты ≥ 48 dp, `Semantics` с текущим значением, состояние не только цветом, отсутствие обрезки при системном увеличении шрифта (FR-027, FR-027a, FR-028, FR-028a)
- [X] T062 [P] Widget-тесты доступности в `app/test/widget/settings_page_test.dart` — покрыть SC-008; каждый тест на `buildTestAppRoot()` завершать `disposeTestAppRoot(tester)`
- [X] T063 Ревью по `project/process/code-quality.md`: KISS/DRY/SOLID/YAGNI, отсутствие force unwrap, небезопасного `as` и `late` без гарантии инициализации
- [X] T064 Gate: `cd app && flutter analyze` без ошибок и `flutter test` полностью зелёный
- [ ] T065 Ручной прогон сценариев 0–3 из [quickstart.md](./quickstart.md) (можно на эмуляторе); сценарий 0 закрывает SC-001, сценарии 1–2 — SC-002 и SC-003
- [ ] T066 Ручной прогон сценариев 4–12 из [quickstart.md](./quickstart.md) на **реальном Android** — включая перезагрузку (сценарий 6), смену часового пояса и ручной перевод часов (сценарий 8, FR-025, FR-025e)
- [ ] T067 Ручной прогон сценариев 4, 7, 8, 11, 12 из [quickstart.md](./quickstart.md) на **реальном iOS** — сценарий 11 (передний план) проверяет делегат из T003; совпадение результатов с T066 закрывает паритет платформ (FR-025a)
- [X] T068 Дописать реальные грабли, потребовавшие переписывания, в `project/process/lessons-learned.md` (гипотетические уроки туда не пишутся)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: без зависимостей, можно начинать сразу
- **Foundational (Phase 2)**: после Setup — **блокирует все истории**
- **US1 (Phase 3)**, **US2 (Phase 4)**, **US5 (Phase 7)**: только Foundational; между собой независимы
- **US3 (Phase 5)**: Foundational + Setup (T002/T003 нужны для реальной доставки)
- **US4 (Phase 6)**: US3 — расширяет уже существующий сервис уведомлений и секцию напоминания
- **Polish (Phase 8)**: после всех историй, которые планируется выпустить

### Внутри историй

- Тесты домена (T024, T047) пишутся до/вместе с реализацией планировщика — он чистая функция, TDD здесь дешёв
- Домен → репозитории → `core/notifications/` → wiring → UI (порядок из plan.md)
- T029 обязателен сразу после T025/T026, иначе проект не собирается

### Критичный порядок

- **T041**: `reconcile()` строго после `AppClock.updateLocation`, иначе FR-025 нарушается молча
- **T029** сразу за T025/T026 — интерфейс без реализации в read-only заглушках ломает сборку
- **T002/T003** до ручных прогонов: без манифеста не работает FR-024, без делегата — FR-016d на iOS

### Parallel Opportunities

- T001, T002, T003 — полностью параллельны (разные файлы, разные платформы)
- T022, T030, T033, T034, T035 внутри US3 — разные файлы, зависимостей между собой нет
- T046, T047, T048 внутри US4 — три независимых тестовых файла
- US1, US2 и US5 после Foundational могут вестись параллельно разными людьми
- Все задачи с ключами `.arb` (T015, T020, T034, T044, T055, T060) конфликтуют по файлам между собой — параллелить их друг с другом **нельзя**, `[P]` у них означает параллельность с задачами других файлов

---

## Parallel Example: User Story 3

```bash
# Независимые файлы, можно запускать одновременно:
Task: "T022 ReminderOccurrence в app/lib/domain/entities/reminder_occurrence.dart"
Task: "T030 Порт NotificationScheduler в app/lib/core/notifications/notification_scheduler.dart"
Task: "T033 reminderTexts в app/lib/core/notifications/reminder_texts.dart"
Task: "T035 Тест на стоп-слова в app/test/core/notifications/reminder_texts_test.dart"
```

---

## Implementation Strategy

### MVP (US1)

1. Phase 1: Setup
2. Phase 2: Foundational — **блокирует всё остальное**
3. Phase 3: US1 (тема)
4. **STOP и проверить**: сценарий 1 из quickstart.md
5. Заглушка `/settings` уже заменена рабочим экраном — это демонстрируемый результат

### Инкрементальная поставка

1. Setup + Foundational → каркас экрана готов
2. + US1 → тема (MVP)
3. + US2 → язык; обе P1-истории закрыты, экран уже полезен
4. + US3 → напоминание доставляется
5. + US4 → напоминание перестаёт отказывать молча; **до этой точки фичу выпускать нельзя** —
   без US4 отказ в разрешении выглядит как «просто не работает»
6. + US5 → звук
7. Polish → доступность, gate, ручные прогоны на устройствах

### Параллельная работа

После Foundational: разработчик A — US1 + US2 (UI-секции), разработчик B — US3 (домен, сервис,
wiring). US4 начинается только после US3. US5 забирает любой освободившийся.

---

## Notes

- `[P]` = разные файлы, нет незакрытых зависимостей
- Коммит после каждой задачи или логической группы
- После правки `@freezed`/`@injectable`/Drift — `dart run build_runner build --delete-conflicting-outputs`; после `.arb` — `flutter gen-l10n`
- **Схема БД не меняется**: колонки `reminder_enabled`/`reminder_time` уже существуют, `schemaVersion` не поднимается
- Новых глобальных Cubit-ов фича не вводит — тройка отказов widget-тестов из `lessons-learned.md` не воспроизводится, но правило `disposeTestAppRoot(tester)` последней строкой остаётся обязательным
