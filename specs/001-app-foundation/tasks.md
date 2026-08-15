---

description: "Task list for feature implementation"
---

# Tasks: Фундамент приложения (Фаза 0)

**Input**: Design documents from `/specs/001-app-foundation/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/)

**Tests**: тестовые задачи включены — конституция (принцип VI) требует `bloc_test` на каждый новый
Cubit, а SC-009 задаёт покрытие новой логики состояния ≥ 70%.

**Organization**: задачи сгруппированы по пользовательским историям спеки, чтобы каждую можно было
реализовать и проверить отдельно.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: можно выполнять параллельно (разные файлы, нет зависимостей)
- **[Story]**: к какой истории относится задача (US1…US5)
- В описании — точный путь к файлу

## Path Conventions

Единый Flutter-модуль: код — `app/lib/`, тесты — `app/test/`. Раскладка — раздел «Project
Structure» в [plan.md](./plan.md).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: привести проект в состояние, в котором конституция не нарушается конфигурацией

- [X] T001 Заменить Riverpod на Cubit-стек в `app/pubspec.yaml`: удалить `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `riverpod_lint`, добавить `flutter_bloc`; выполнить `flutter pub get`
- [X] T002 [P] Переключить шаблонный ARB на русский в `app/l10n.yaml` (`template-arb-file: intl_ru.arb`) и синхронизировать ключи в `app/lib/l10n/intl_ru.arb`, `intl_uk.arb`, `intl_en.arb`
- [X] T003 [P] Задать константы фазы в `app/lib/core/constants/app_constants.dart`: `minTapTargetDp = 48`, `duplicateFailureWindow = Duration(seconds: 3)`, `maxDayTextLength = 2000`, `dayRolloverTolerance = Duration(seconds: 60)`
- [X] T004 [P] Выключить диагностику в релизе в `app/lib/core/utils/app_logger.dart`: `Level.off` при `kReleaseMode`, `Level.debug` иначе (FR-016c)
- [X] T005 [P] Отключить системный автобэкап файлов БД: `android:allowBackup="false"` и `android:fullBackupContent` в `app/android/app/src/main/AndroidManifest.xml`; на iOS исключить файл БД из резервного копирования (флаг «не бэкапить» на каталоге хранилища) в `app/lib/core/bootstrap/app_bootstrap.dart` (FR-016d)
- [X] T006 Создать каркас каталогов `app/lib/app/`, `app/lib/domain/`, `app/lib/data/`, `app/lib/presentation/`, `app/test/support/` согласно разделу «Project Structure» плана

**Checkpoint**: `flutter analyze` проходит, Riverpod в проекте отсутствует

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: время, схема хранилища, сущности и путь ошибок — на этом стоят все пять историй

**⚠️ CRITICAL**: ни одна история не начинается, пока эта фаза не закрыта

### Время

- [X] T007 Определить контракт `AppClock` (`nowUtc`, `location`, `minuteTicks`, `updateLocation`) в `app/lib/core/app_clock/app_clock.dart` по [contracts/app-clock.md](./contracts/app-clock.md)
- [X] T008 Реализовать `SystemAppClock` в `app/lib/core/app_clock/system_app_clock.dart`: `DateTime.now().toUtc()`, выровненный минутный `Timer.periodic`, broadcast-стрим, `dispose()` с отменой таймера
- [X] T009 [P] Реализовать `FakeAppClock` в `app/test/support/fake_app_clock.dart`: ручные `set now`, `set location`, `emitTick(DateTime)`, без реальных таймеров
- [X] T010 Реализовать `DayResolver.resolve` и `DayResolver.boundsUtc` в `app/lib/domain/services/day_resolver.dart` через `tz.TZDateTime` (FR-009, FR-023b)
- [X] T011 [P] Написать юнит-тесты `DayResolver` в `app/test/core/day_resolver_test.dart`: `dayStartHour` 0 и 4, пояса `Europe/Kyiv` и `Pacific/Kiritimati`, DST в `America/Sao_Paulo`, пропущенный при переводе час, неизменность `occurredAt` при смене пояса (FR-023b, FR-024, FR-026)

### Сущности и правила валидации

- [X] T012 [P] Создать value objects `MoodScore`, `DayStartHour`, `ReactionTone`, `ThemePreference`, `LocalePreference`, `ReminderTime` в `app/lib/domain/value_objects/` с фабриками, возвращающими `Result<T>` (правила — [data-model.md](./data-model.md))
- [X] T013 [P] Создать `DayKey` (сравнимый, сортируемый) в `app/lib/domain/entities/day_key.dart`
- [X] T014 [P] Создать Freezed-сущности `DayEntry`, `CharacterReaction`, `UserSettings` в `app/lib/domain/entities/` — без Drift и Flutter импортов
- [X] T015 [P] Написать юнит-тесты валидации value objects в `app/test/core/value_objects_test.dart` (границы 1–5, 0–23, 0.0–1.0, длина текста 2000, непустой список персонажей)

### Хранилище

- [X] T016 Описать таблицы `day_entries` и `character_reactions` в `app/lib/data/datasources/drift/tables/diary_tables.dart` с `check`-ограничениями, FK `onDelete: cascade` и индексами по [data-model.md](./data-model.md)
- [X] T017 [P] Описать таблицу `user_settings` (синглтон, `check(id = 1)`, `dayStartHour` 0–23) в `app/lib/data/datasources/drift/tables/app_tables.dart`
- [X] T018 Создать `AppDatabase` в `app/lib/data/datasources/drift/app_database.dart`: `schemaVersion = 1`, без `MigrationStrategy`, `PRAGMA foreign_keys = ON` в `beforeOpen`
- [X] T019 Выполнить `dart run build_runner build --delete-conflicting-outputs` в `app/` и зафиксировать сгенерированный код Drift/Freezed
- [X] T020 [P] Создать тестовую БД на памяти в `app/test/support/test_database.dart` (`NativeDatabase.memory()` + сид настроек по умолчанию)

### Ошибки и DI

- [X] T021 Добавить коды `storageUnavailable`, `storageReadOnly` в `DatabaseFailure` и коды правил валидации в `ValidationFailure` в `app/lib/core/errors/app_failure.dart` с ветками `localizedMessage` (FR-019a, FR-020)
- [X] T022 [P] Добавить строки новых кодов ошибок в `app/lib/l10n/intl_ru.arb` и заготовки в `intl_uk.arb`, `intl_en.arb`
- [X] T023 Перевести логирование `SafeCallMixin` и `TimeZones` на `app_logger` в `app/lib/core/errors/safe_call_mixin.dart` и `app/lib/core/time_zone/time_zones.dart` — единственная точка отключения диагностики (FR-016c)
- [X] T024 [P] Создать моки репозиториев и `AppClock` на `mocktail` в `app/test/support/mocks.dart`

**Checkpoint**: время, схема и сущности готовы — истории можно вести параллельно

---

## Phase 3: User Story 1 — Оболочка с тремя разделами (Priority: P1) 🎯 MVP

**Goal**: приложение открывается в собственную оболочку с нижней навигацией и заглушками разделов
вместо демо-экрана шаблона.

**Independent Test**: установить сборку, пройти по трём разделам и обратно, свернуть и развернуть
приложение, нажать системную «Назад» на корневом разделе.

### Tests for User Story 1

- [X] T025 [P] [US1] Widget-тест навигации в `app/test/widget/shell_navigation_test.dart`: стартовый раздел «Стол», переключение всех трёх вкладок, сохранение состояния ветки, отсутствие перестроения оболочки (FR-002, FR-004)
- [X] T026 [P] [US1] Widget-тест доступности в `app/test/widget/shell_accessibility_test.dart`: `meetsGuideline(androidTapTargetGuideline)` и `labeledTapTargetGuideline` для пунктов навигации (FR-030, SC-010)

### Implementation for User Story 1

- [X] T027 [P] [US1] Объявить константы маршрутов `/table`, `/diary`, `/settings`, `/onboarding`, `/storage-error` в `app/lib/app/router/app_routes.dart`
- [X] T028 [P] [US1] Создать страницы-заглушки с названием раздела из l10n в `app/lib/presentation/table/table_placeholder_page.dart`, `app/lib/presentation/diary/diary_placeholder_page.dart`, `app/lib/presentation/settings/settings_placeholder_page.dart`
- [X] T029 [P] [US1] Создать заглушку онбординга в `app/lib/presentation/onboarding/onboarding_placeholder_page.dart` (маршрут без redirect-гарда — FR-006)
- [X] T030 [US1] Собрать роутер на `StatefulShellRoute.indexedStack` с тремя ветками в `app/lib/app/router/app_router.dart` (зависит от T027, T028, T029)
- [X] T031 [US1] Создать `ShellPage` (`Scaffold` + `NavigationBar`, `Semantics` на каждом пункте) в `app/lib/app/shell/shell_page.dart`
- [X] T032 [US1] Создать `AppMaterialRouter` (`MaterialApp.router`, тема из `core/theme`, `supportedLocales: [ru, uk, en]`, `localeResolutionCallback` → ru) в `app/lib/app/app_material_router.dart` (FR-029, US5.3)
- [X] T033 [US1] Заменить демо-экран на реальную точку входа в `app/lib/main.dart` и `app/lib/app/app_root.dart`: инициализация `TimeZones`, DI, `runApp(AppRoot)` (FR-001)

**Checkpoint**: приложение запускается в оболочку и по ней можно ходить; хранилище ещё не задействовано

---

## Phase 4: User Story 2 — Данные сохраняются между запусками (Priority: P1)

**Goal**: локальное хранилище принимает записи дня, реакции персонажей и настройки; данные
переживают перезапуск.

**Independent Test**: записать данные всех трёх видов, перезапустить приложение, прочитать обратно
и сверить значения.

### Tests for User Story 2

- [X] T034 [P] [US2] Тесты схемы и мапперов в `app/test/data/app_database_test.dart`: создание БД, единственная строка настроек со значениями по умолчанию, каскадное удаление реакций, реакция с тоном вне перечня сохраняется с нейтральным тоном и неизменным текстом (FR-010b, FR-011, FR-013, SC-015)
- [X] T035 [P] [US2] Тесты `DiaryRepository` в `app/test/data/diary_repository_test.dart`: повторное сохранение за день обновляет запись, одновременные сохранения дают одну запись, две записи в одном дне после смены `dayStartHour` доступны обе, `entryForDay` отдаёт позднюю, при равных `occurredAt` — позже созданную, `updatedAt` не меняется при добавлении реакции (FR-007b, FR-009a…e, SC-008, SC-012)
- [X] T036 [P] [US2] Тесты `SettingsRepository` в `app/test/data/settings_repository_test.dart`: `installId` неизменен между вызовами, `updateThemeMode`/`updateDayStartHour` возвращают полное состояние, `watch()` эмитит после изменения (FR-014, SC-003)

### Implementation for User Story 2

- [X] T037 [P] [US2] Реализовать DAO-обёртку над `day_entries`/`character_reactions` в `app/lib/data/datasources/diary_local_datasource.dart` (выборки диапазоном, сортировка `occurredAt DESC, id DESC`)
- [X] T038 [P] [US2] Реализовать DAO-обёртку над `user_settings` с созданием строки по умолчанию и генерацией `installId` (`Random.secure()`, 32 hex) в `app/lib/data/datasources/settings_local_datasource.dart` (FR-014, FR-015a)
- [X] T039 [P] [US2] Реализовать мапперы Model ↔ Entity в `app/lib/data/mappers/day_entry_mapper.dart`, `character_reaction_mapper.dart`, `user_settings_mapper.dart`; неизвестный тон → `neutral` с записью в диагностику только в debug (FR-010b)
- [X] T040 [US2] Объявить контракты `DiaryRepository` и `SettingsRepository` в `app/lib/domain/repositories/` по [contracts/repositories.md](./contracts/repositories.md)
- [X] T041 [US2] Реализовать `DiaryRepositoryImpl` в `app/lib/data/repositories/diary_repository_impl.dart`: `saveTodayEntry` в транзакции (вычислить `DayKey` → границы → обновить/вставить), `SafeCallMixin`, `Result<T>` (зависит от T037, T039, T040)
- [X] T042 [US2] Реализовать `SettingsRepositoryImpl` в `app/lib/data/repositories/settings_repository_impl.dart` с `watch()` поверх Drift-стрима (зависит от T038, T039, T040)
- [X] T043 [US2] Зарегистрировать БД, datasources и репозитории в DI в `app/lib/core/di/injection_module.dart` и выполнить `dart run build_runner build`

**Checkpoint**: данные всех трёх видов читаются и пишутся, правило одной записи на день соблюдается

---

## Phase 5: User Story 3 — Ошибка доходит до пользователя понятным сообщением (Priority: P2)

**Goal**: любая операция завершается результатом или описанной ошибкой; недоступное хранилище не
роняет приложение, а даёт выбор действия.

**Independent Test**: вызвать сбой хранилища и убедиться, что приложение работоспособно и
показывает локализованное сообщение; испортить файл БД и пройти сценарий восстановления.

### Tests for User Story 3

- [X] T044 [P] [US3] Юнит-тесты `FailureToastGate` в `app/test/core/failure_toast_gate_test.dart`: десять одинаковых ошибок за секунду → один показ, другой вид → показ сразу, окно 3 с (FR-021f, FR-021g, SC-014)
- [X] T045 [P] [US3] `bloc_test` для `StorageRecoveryCubit` в `app/test/presentation/storage_recovery_cubit_test.dart`: сбой открытия → `idle(cause)`, сбой сброса → `error` с сохранением действий, успешный `retry` → `recovered`, `isClosed` после `await` (FR-021c1, FR-021e1)
- [X] T046 [P] [US3] Тест режима без сохранения в `app/test/data/read_only_repositories_test.dart`: чтение отдаёт пустые данные и умолчания, запись → `DatabaseFailure(storageReadOnly)`, `installId` не сохраняется (FR-021d, FR-021d2)

### Implementation for User Story 3

- [X] T047 [P] [US3] Реализовать `FailureToastGate` (ключ `(runtimeType, code)`, время из `AppClock`) в `app/lib/core/errors/failure_toast_gate.dart`
- [X] T048 [P] [US3] Объявить `StorageMode` (`persistent | readOnly | unavailable`) в `app/lib/core/bootstrap/storage_mode.dart`
- [X] T049 [US3] Реализовать `AppBootstrap.start()` в `app/lib/core/bootstrap/app_bootstrap.dart`: открытие БД, проба `SELECT 1` + строка настроек, `Result<AppSession>`, сброс данных с удалением файлов БД и `-wal`/`-shm` (FR-021a, FR-021c)
- [X] T050 [US3] Реализовать `ReadOnlySettingsRepository` и `UnavailableDiaryRepository` в `app/lib/data/repositories/read_only_repositories.dart` (зависит от T040)
- [X] T051 [US3] Реализовать `StorageRecoveryCubit` и его состояния в `app/lib/presentation/storage_recovery/cubit/` (Freezed sealed, действия `retry`/`resetData`/`continueWithoutSaving`)
- [X] T052 [US3] Создать `StorageRecoveryPage` в `app/lib/presentation/storage_recovery/storage_recovery_page.dart`: объяснение причины, три действия, диалог подтверждения с предупреждением о необратимости, системные тема и язык (FR-021b, FR-021b1, FR-021c2, FR-030)
- [X] T053 [US3] Создать баннер режима без сохранения в `app/lib/app/shell/widgets/read_only_banner.dart` и встроить в `ShellPage` (FR-021e)
- [X] T054 [US3] Реализовать `RootBlocListener` с показом тостов через `FailureToastGate` и `AppFailure.localizedMessage` в `app/lib/app/root_bloc_listener.dart`; подключить редирект на `/storage-error` и подмену репозиториев в DI по `StorageMode` (зависит от T047, T049, T050)

**Checkpoint**: сбои видны пользователю, приложение не падает и ничего не удаляет молча

---

## Phase 6: User Story 4 — Единообразная дата дня и переход границы суток (Priority: P2)

**Goal**: «текущий день» обновляется без перезапуска, пересчитывается при смене пояса и «часа
начала дня».

**Independent Test**: сдвинуть время через границу суток и сменить пояс в контролируемых условиях;
убедиться, что день меняется без перезапуска и без потери данных.

### Tests for User Story 4

- [ ] T055 [P] [US4] `bloc_test` для `CurrentDayCubit` в `app/test/presentation/current_day_cubit_test.dart`: тик через границу при `dayStartHour` 0 и 4 меняет день, тик внутри дня не эмитит состояние, смена пояса пересчитывает день, `isClosed` после `await` (FR-023, FR-023a, SC-007)
- [ ] T056 [P] [US4] Тест пересчёта дней при смене `dayStartHour` в `app/test/data/day_recalculation_test.dart`: сохранённые моменты не меняются, записи остаются доступны, дни пересчитаны (FR-026, FR-026b, SC-011)

### Implementation for User Story 4

- [ ] T057 [US4] Реализовать `CurrentDayCubit` и состояния в `app/lib/presentation/app_settings/cubit/current_day_cubit.dart`: подписка на `minuteTicks`, эмиссия только при смене `DayKey`, значение берётся из момента тика
- [ ] T058 [US4] Подключить `CurrentDayCubit` к изменению `dayStartHour` из настроек (пересчёт при обновлении) в `app/lib/presentation/app_settings/cubit/current_day_cubit.dart`
- [ ] T059 [US4] Добавить обработку `AppLifecycleState.resumed` в `app/lib/app/app_root.dart`: перечитать системный пояс, при изменении вызвать `AppClock.updateLocation` и пересчитать день (FR-026a)
- [ ] T060 [US4] Зарегистрировать `AppClock`, `DayResolver` и `CurrentDayCubit` в DI и в `MultiBlocProvider` в `app/lib/core/di/injection_module.dart` и `app/lib/app/app_root.dart`
- [ ] T061 [US4] Проверить отсутствие прямых вызовов времени: `grep -rn "DateTime.now()" app/lib/` — единственное вхождение в `app/lib/core/app_clock/system_app_clock.dart` (принцип IV)

**Checkpoint**: границы суток и смена пояса воспроизводимы автотестами

---

## Phase 7: User Story 5 — Тема и язык применяются мгновенно (Priority: P3)

**Goal**: сохранённые тема и язык применяются ко всему приложению без перезапуска; по умолчанию —
системные значения.

**Independent Test**: изменить сохранённые тему и язык без перезапуска и увидеть мгновенное
применение на всех разделах.

### Tests for User Story 5

- [ ] T062 [P] [US5] `bloc_test` для `AppSettingsCubit` в `app/test/presentation/app_settings_cubit_test.dart`: поток настроек → `loaded`, ошибка загрузки → `error` с откатом на системные значения, `isClosed` после `await`
- [ ] T063 [P] [US5] Widget-тест мгновенного применения в `app/test/widget/theme_locale_test.dart`: смена темы и языка перерисовывает все три раздела без перезапуска; неподдерживаемый язык → русский (SC-006, US5.3)

### Implementation for User Story 5

- [ ] T064 [US5] Реализовать `AppSettingsCubit` и его состояния в `app/lib/presentation/app_settings/cubit/app_settings_cubit.dart` (подписка на `SettingsRepository.watch()`)
- [ ] T065 [US5] Подключить `AppSettingsCubit` к `MaterialApp.router` через `BlocBuilder` в `app/lib/app/app_material_router.dart`: `themeMode` и `locale`, состояние `initial` трактуется как системные значения (FR-027, FR-021b1)
- [ ] T066 [US5] Зарегистрировать `AppSettingsCubit` в `MultiBlocProvider` в `app/lib/app/app_root.dart` и связать с `RootBlocListener`
- [ ] T067 [US5] Проверить полноту переводов: `flutter gen-l10n` без записей в `app/lib/gen/untranslated_messages.json` для `ru`, отсутствие технических ключей на экранах (FR-029)

**Checkpoint**: все пять историй работают независимо

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T068 [P] Добавить механизм внедрения ошибок только для отладочной сборки в `app/lib/core/bootstrap/debug_failure_injector.dart` — источник управляемых сбоев для SC-004 и SC-016
- [ ] T069 [P] Реализовать экран ошибки запуска вне хранилища с действием «повторить» в `app/lib/presentation/storage_recovery/startup_error_page.dart` (FR-018a)
- [ ] T070 Прогнать gate: `flutter analyze` без ошибок и `flutter test --coverage` в `app/`; довести покрытие новой логики состояния до ≥ 70% (SC-009)
- [ ] T071 [P] Выполнить ручной прогон по таблице «Ручной прогон на устройстве» из [quickstart.md](./quickstart.md) на реальном среднем устройстве (SC-001, SC-004, SC-013)
- [ ] T072 [P] Проверить приватность и диагностику: `grep -rn "print(\|debugPrint(\|dart:developer" app/lib/` — только `app_logger`; в логах нет `dayText`, `moodScore`, текста реплик; в `app/pubspec.yaml` нет пакетов аналитики, телеметрии и сбора крашей (FR-016a, FR-016b, FR-016c)
- [ ] T073 [P] Обновить `project/architecture/architecture-full.md`: `AppClock` с `location`, `DayResolver` в `domain/services/`, `domain/value_objects/`, `core/bootstrap/`, глобальные Cubit в `presentation/app_settings/`, режим без сохранения (`architecture-brief.md` уже приведён в соответствие)
- [ ] T074 Записать реальные грабли фазы в `project/process/lessons-learned.md` — только то, что действительно потребовало переписывания (рабочий процесс, п. 7)

---

## Dependencies & Execution Order

### Порядок фаз

1. **Setup (Phase 1)** — блокирует всё
2. **Foundational (Phase 2)** — блокирует все истории
3. **US1 (Phase 3)** и **US2 (Phase 4)** — независимы друг от друга, обе P1
4. **US3 (Phase 5)** — нужен `AppBootstrap`, опирается на репозитории из US2 и оболочку из US1
5. **US4 (Phase 6)** — нужен `AppClock` (Foundational) и оболочка US1; данные US2 нужны только
   для теста T056
6. **US5 (Phase 7)** — нужен `SettingsRepository` (US2) и `AppMaterialRouter` (US1)
7. **Polish (Phase 8)** — после всех историй

### Зависимости внутри фаз

- T008, T010 → T007
- T016, T017 → T018 → T019 → T020
- T030 → T027, T028, T029
- T041 → T037, T039, T040; T042 → T038, T039, T040
- T054 → T047, T049, T050
- T059, T060 → T057
- T065 → T064
- T069 относится к пути ошибок US3 и вынесен в Polish только потому, что не блокирует остальные
  истории — выполнять после T054
- T071 → T068: ручной прогон SC-004 и SC-016 невозможен без механизма внедрения ошибок

### Параллельные возможности

**Phase 1**: T002, T003, T004, T005 — разные файлы, идут одновременно.

**Phase 2**: три группы параллельны между собой — время (T009, T011), сущности (T012–T015),
хранилище (T017, T020), плюс T022 и T024.

**Phase 3–4**: после Foundational US1 и US2 можно вести двумя параллельными потоками; внутри US1
параллельны T025, T026, T027, T028, T029; внутри US2 — T034, T035, T036 и T037, T038, T039.

**Phase 5–7**: тестовые задачи каждой истории (T044–T046, T055–T056, T062–T063) пишутся
параллельно с реализацией той же истории.

**Phase 8**: T068, T069, T071, T072, T073 — независимы.

---

## Implementation Strategy

**MVP (минимальный демонстрируемый результат)**: Phase 1 + Phase 2 + Phase 3 (US1) — приложение
запускается в собственную оболочку и по ней можно ходить. Это первый результат, который видно
без единого готового экрана.

**Инкремент 2**: Phase 4 (US2) — доказанная сохранность данных всех трёх видов.

**Инкремент 3**: Phase 5 (US3) — ни одного видимого краша, включая испорченное хранилище.

**Инкремент 4**: Phase 6 + Phase 7 (US4, US5) — воспроизводимое поведение времени и мгновенная
смена темы/языка.

**Завершение**: Phase 8 — измеримые критерии, ручной прогон на устройстве, синхронизация
документации.

**Gate на каждой задаче** (конституция, рабочий процесс п. 5): `flutter analyze` без ошибок и
`flutter test` полностью зелёный. Задача с падающими тестами не считается выполненной.
`dart run build_runner build` — после любой правки `@freezed`, `@injectable` или Drift-таблиц.
