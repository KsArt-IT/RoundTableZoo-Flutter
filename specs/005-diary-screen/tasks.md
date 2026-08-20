---

description: "Task list for 005-diary-screen"
---

# Tasks: Экран «Дневник»

**Input**: Design documents from `/specs/005-diary-screen/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: включены — не по умолчанию шаблона, а по требованию конституции §VI (каждый новый Cubit
покрыт `bloc_test`, цель >70%) и плану тестов `research.md` R16.

**Organization**: задачи сгруппированы по user stories из `spec.md`, чтобы каждую можно было
реализовать и проверить независимо.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: можно выполнять параллельно (разные файлы, нет зависимостей от незавершённых задач)
- **[Story]**: к какой user story относится задача (US1..US4)
- В описании — точный путь к файлу

## Path Conventions

Мобильное приложение, слоистая архитектура. Корень модуля — `app/`; исходники `app/lib/`, тесты
`app/test/`. Все пути ниже — от корня репозитория.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: зависимости, константы и строки, нужные всем историям

- [X] T001 Добавить `fl_chart: ^1.2.0` в секцию `dependencies` файла `app/pubspec.yaml` и выполнить `flutter pub get` (research.md R1; версия уже в `~/.pub-cache`, сеть не требуется)
- [X] T002 [P] Добавить константы Дневника в `app/lib/core/constants/app_constants.dart`: `diaryPageSize`, `diaryPrefetchThreshold`, `diaryExportBatchSize`, `diaryRefreshDebounce`, `diaryChartDailyMaxDays`, `diaryChartWeeklyMaxDays`, `diaryChartMaxScale`, `diaryChartInitialDays`, `diaryChartMinValue`, `diaryChartMaxValue` (data-model.md §5)
- [X] T003 [P] Добавить строки Дневника во все три файла `app/lib/l10n/intl_ru.arb`, `intl_en.arb`, `intl_uk.arb` — пустое состояние, «дальше дней нет», ошибка загрузки и «повторить», «хранилище недоступно», «реплик не было», подписи «раскрыть/свернуть», «экспорт», ошибка догрузки страницы, подписи `Semantics` для иконочных кнопок (FR-028; все три локали заполняются сразу — норма проекта, `untranslated_messages.json` должен остаться пустым)
- [X] T004 Выполнить `flutter gen-l10n` в `app/` и убедиться, что `app/lib/gen/untranslated_messages.json` пуст

**Checkpoint**: зависимости и строки на месте, кодогенерация локализации проходит

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: каркас экрана, состояние и DI — без этого ни одна история не может начаться

**⚠️ CRITICAL**: ни одна user story не начинается, пока эта фаза не завершена

- [X] T005 Создать `app/lib/presentation/diary/cubit/diary_state.dart`: Freezed sealed `DiaryState` (`initial`/`loading`/`loaded`/`unavailable`/`error`), `DiaryData` (поля `days`, `chart`, `characters`, `hasMore`, `loadingMore`, `exporting`, `pageFailure`, геттеры `isEmpty`/`canExport`) и `DiaryDay` (`record`, `expanded`, `reactionsLoading`, `reactions`, геттеры `day`/`entry`/`entryId`) — data-model.md §3, §4. Рядом с `entryId` — комментарий-обоснование force unwrap `entry.id!` (конституция §VI требует его в коде, не только в ревью)
- [X] T006 Создать каркас `app/lib/presentation/diary/cubit/diary_cubit.dart`: конструктор с `DiaryRepository` и `CharacterCatalog`, поток `failures`, `close()` с отменой подписок; методы-заглушки по contracts/diary-cubit.md §2 (тела наполняются в фазах US1–US4). `ExportDiaryToCsv` и `ShareService` здесь **не** объявляются — они появляются в US4 (T054), иначе фаза Foundational не соберётся до самой низкоприоритетной истории
- [X] T007 Зарегистрировать `DiaryCubit` как `@injectable`-фабрику (не `@lazySingleton` — research.md R14) в `app/lib/core/di/injection_module.dart`
- [X] T008 Создать `app/lib/presentation/diary/diary_page.dart` с `BlocProvider(create: (_) => getIt<DiaryCubit>()..load())` и пустым телом `BlocBuilder` по всем пяти состояниям
- [X] T009 Переключить ветку `/diary` в `app/lib/app/router/app_router.dart` с `DiaryPlaceholderPage` на `DiaryPage` и удалить `app/lib/presentation/diary/diary_placeholder_page.dart`
- [X] T010 Создать `app/lib/domain/entities/diary_day_entry.dart` (Freezed `DiaryDayEntry(DayKey day, DayEntry entry)`) и `app/lib/domain/entities/diary_page.dart` (Freezed `DiaryPage(List<DiaryDayEntry> days, bool hasMore, DateTime? nextCursor)`) — data-model.md §2; `DayEntry` поля дня не имеет, а `dayStartHour` не должен покидать `data/` (research.md R2, R15)
- [X] T011 Выполнить `dart run build_runner build --delete-conflicting-outputs` в `app/` и убедиться, что `flutter analyze` не даёт ошибок

**Checkpoint**: вкладка «Дневник» открывается на новом экране, состояния объявлены — можно начинать истории

---

## Phase 3: User Story 1 — Просмотреть историю настроения (Priority: P1) 🎯 MVP

**Goal**: список прошлых дней в обратном хронологическом порядке с постраничной подгрузкой,
работающий офлайн, с явными пустым состоянием, ошибкой и режимом «только чтение».

**Independent Test**: отметить настроение за несколько дней через Стол → открыть Дневник в
авиарежиме → увидеть все дни списком, самый новый сверху; докрутить до конца → подгружаются более
старые дни без дублей, в конце — явное «дальше дней нет».

### Tests for User Story 1 ⚠️

> Пишутся до реализации и должны падать до неё

- [X] T012 [P] [US1] Добавить в `app/test/data/diary_repository_test.dart` тесты `entriesPage`: первая страница без курсора, страница по `nextCursor` предыдущей, схлопывание нескольких записей одного дня до самой поздней по `occurredAt`, `hasMore == true` ровно когда прочитано `limit` строк, `nextCursor` равен **началу** последнего дня страницы, день с несколькими записями на границе страниц не приходит дважды, весь `limit` строк в одном дне всё равно двигает курсор, пустая БД, `limit <= 0` → `ValidationFailure` (contracts/diary-repository.md §1)
- [X] T013 [P] [US1] Создать `app/test/presentation/diary_cubit_test.dart` со сценариями 1–8, 12, 16–19 из contracts/diary-cubit.md §4 (загрузка, пустая история, `storageReadOnly` → `unavailable`, прочий failure → `error` + `retry`, подгрузка без дублей, двойной `loadMore` = один запрос, `hasMore: false`, перечитывание первой страницы по `watchEntriesChanged`, `isClosed` после `await`, `pageFailure` и его очистка, день на границе страниц не дублируется). Проверка «раскрытые дни сохранены» — не здесь: `toggleDay` появляется только в US3 (T038)
- [X] T014 [P] [US1] Создать `app/test/widget/diary_page_test.dart` с проверками: пустое состояние вместо пустого списка, порядок дней от новых к старым, день без текста рисуется без заглушки, футер «дальше дней нет» вместо индикатора. Последней строкой каждого теста — `disposeTestAppRoot(tester)` (lessons-learned: Drift `watch()` оставляет висящий таймер)

### Implementation for User Story 1

- [X] T015 [US1] Добавить в `app/lib/data/datasources/diary_local_datasource.dart` метод `entriesBefore(DateTime? beforeUtc, int limit)` — `occurredAt < beforeUtc ORDER BY occurredAt DESC, id DESC LIMIT n` по существующему индексу `idx_day_entries_occurred_at`
- [X] T016 [US1] Объявить `Future<Result<DiaryPage>> entriesPage({DateTime? beforeOccurredAt, required int limit})` в `app/lib/domain/repositories/diary_repository.dart` (contracts/diary-repository.md §1)
- [X] T017 [US1] Реализовать `entriesPage` в `app/lib/data/repositories/diary_repository_impl.dart`: `safeCall`, схлопывание строк в дни через `DayResolver` + `dayStartHour` из настроек, `hasMore = (прочитано строк == limit)`, `nextCursor = DayResolver.boundsUtc(последний день).startUtc` (**начало дня**, не `occurredAt` записи — иначе день вернётся на следующей странице повторно, нарушив FR-004b/FR-006), валидация `limit` (research.md R2, R15)
- [X] T018 [P] [US1] Реализовать `entriesPage` в `UnavailableDiaryRepository` (`app/lib/data/repositories/read_only_repositories.dart`) → `DatabaseFailure(code: storageReadOnly)`
- [X] T019 [US1] Реализовать `DiaryCubit.load()` и `retry()` в `app/lib/presentation/diary/cubit/diary_cubit.dart`: `loading` → первая страница → `loaded`/`unavailable`/`error`; различение `unavailable` по `code == DatabaseFailure.storageReadOnly` (research.md R13); `chart` на этом этапе — пустой список (наполняется в US2, T035); `if (isClosed) return;` после каждого `await`
- [X] T020 [US1] Реализовать `DiaryCubit.loadMore()` в `app/lib/presentation/diary/cubit/diary_cubit.dart`: курсор — `DiaryPage.nextCursor` предыдущей страницы, no-op при `loadingMore`/`!hasMore`, слияние с дедупликацией по `DayKey` (не по `entryId` — повтор возможен только на уровне дня, и `id` у повторной строки другой; FR-004b, FR-006), `hasMore` берётся из `DiaryPage` как есть, запись `pageFailure` вместо перехода в `error` (research.md R19)
- [X] T021 [US1] Подписать `DiaryCubit` в `app/lib/presentation/diary/cubit/diary_cubit.dart` на `diaryRepository.watchEntriesChanged()` с дебаунсом `AppConstants.diaryRefreshDebounce`: перечитывается только первая страница, старые страницы и раскрытые дни сохраняются (research.md R12); отмена подписки в `close()`
- [X] T022 [P] [US1] Создать `app/lib/presentation/diary/widgets/diary_day_card.dart`: дата из `DiaryDay.day` через `DateFormat.yMMMMd(l10n.localeName)` (research.md R17), эмодзи из `MoodScale.fromValue`, обрезанный текст дня, корректный вид дня без текста (FR-001, FR-005)
- [X] T023 [P] [US1] Создать `app/lib/presentation/diary/widgets/diary_empty_view.dart` — явное пустое состояние с подсказкой отметить настроение на Столе (FR-007)
- [X] T024 [P] [US1] Создать `app/lib/presentation/diary/widgets/diary_error_view.dart` — два различимых баннера: ошибка с кнопкой «повторить» (FR-008a) и «хранилище недоступно» без слов «записей нет» (FR-029), текст только из `AppFailure.localizedMessage`
- [X] T025 [US1] Собрать список в `app/lib/presentation/diary/diary_page.dart`: `ListView.builder`, старт подгрузки при `diaryPrefetchThreshold` до конца, индикатор первой страницы на месте списка и индикатор догрузки в футере, строка «дальше дней нет», строка `pageFailure` с повтором (research.md R19)

**Checkpoint**: US1 полностью работает и проверяется независимо — это MVP среза

---

## Phase 4: User Story 2 — Видеть тренд настроения на графике (Priority: P2)

**Goal**: график настроения по всей истории с агрегацией по объёму, зумом и разрывами на днях без
записи, строящийся исключительно по `moodScore`.

**Independent Test**: отметить настроение с разными значениями за несколько дней, оставив один день
пустым → открыть Дневник → точка на каждый день совпадает со значением в списке, пустой день —
разрыв; развести пальцы → диапазон сужается, агрегация переходит на дневную.

### Tests for User Story 2 ⚠️

- [X] T026 [P] [US2] Добавить в `app/test/data/diary_repository_test.dart` тесты `moodHistory`: порядок по возрастанию дня, одна точка на день при нескольких записях, пустая БД → пустой список, `storageReadOnly` (contracts/diary-repository.md §2)
- [X] T027 [P] [US2] Создать `app/test/presentation/mood_chart_aggregation_test.dart` на чистую функцию свёртки ряда: дневная/недельная/месячная гранулярность по порогам, среднее только по дням с записью, полностью пустой период → разрыв, ряд из одной точки (research.md R5); отдельным кейсом — набор из 10 дней со смешанными оценками, где каждая дневная точка равна сохранённому `moodScore` этого дня (SC-002)

### Implementation for User Story 2

- [X] T028 [P] [US2] Создать `app/lib/domain/entities/mood_chart_point.dart` — Freezed `MoodChartPoint(DayKey day, MoodScore moodScore)` (data-model.md §2)
- [X] T029 [US2] Добавить в `app/lib/data/datasources/diary_local_datasource.dart` метод `moodProjection()` — выборка только `occurredAt` и `moodScore` по всей таблице, `occurredAt DESC` (research.md R3)
- [X] T030 [US2] Добавить маппинг проекции в `MoodChartPoint` в `app/lib/data/mappers/day_entry_mapper.dart`
- [X] T031 [US2] Объявить `moodHistory()` в `app/lib/domain/repositories/diary_repository.dart` и реализовать в `app/lib/data/repositories/diary_repository_impl.dart`: схлопывание по `DayResolver`, сортировка по возрастанию дня
- [X] T032 [P] [US2] Реализовать `moodHistory()` в `UnavailableDiaryRepository` (`app/lib/data/repositories/read_only_repositories.dart`) → `storageReadOnly`
- [X] T033 [US2] Реализовать чистую функцию свёртки дневного ряда в точки видимой гранулярности (день/неделя/месяц по `diaryChartDailyMaxDays`/`diaryChartWeeklyMaxDays`, среднее по дням с записью) в `app/lib/presentation/diary/widgets/mood_chart.dart` — отдельной top-level функцией, тестируемой без виджета
- [X] T034 [US2] Реализовать сам виджет графика в `app/lib/presentation/diary/widgets/mood_chart.dart`: `LineChart`, `FlSpot.nullSpot` для пропусков (FR-012), фиксированная ось значений `diaryChartMinValue`..`diaryChartMaxValue` (research.md R18), `FlTransformationConfig(scaleAxis: FlScaleAxis.horizontal, maxScale: diaryChartMaxScale)` с собственным `TransformationController`, пересчёт гранулярности по видимому диапазону (research.md R6), стартовый диапазон `diaryChartInitialDays` с правым краем у самого свежего дня, `ExcludeSemantics` как декоративный элемент (FR-013a)
- [X] T035 [US2] Загружать `moodHistory()` в `DiaryCubit.load()`/`retry()` и в обработчике `watchEntriesChanged` (research.md R12), класть в `DiaryData.chart`
- [X] T036 [US2] Разместить график над списком в `app/lib/presentation/diary/diary_page.dart`, не ломая прокрутку списка

**Checkpoint**: US1 и US2 работают независимо друг от друга

---

## Phase 5: User Story 3 — Прочитать реплики зверей за день (Priority: P3)

**Goal**: раскрытие карточки дня показывает полный текст дня и все сохранённые реплики персонажей,
включая переспросы; раскрытия дней независимы.

**Independent Test**: на Столе получить две реплики одного персонажа за день и одну реплику
другого → открыть Дневник → раскрыть день → увидеть все три реплики с именами; раскрыть второй
день → первый остаётся раскрытым.

### Tests for User Story 3 ⚠️

- [X] T037 [P] [US3] Добавить в `app/test/presentation/diary_cubit_test.dart` сценарии 9–11 из contracts/diary-cubit.md §4: реплики грузятся один раз и кэшируются, два дня раскрыты одновременно, день без реплик даёт `reactions == []` (а не `null`); плюс перенесённая из T013 проверка, что сигнал `watchEntriesChanged` не сворачивает уже раскрытые дни
- [X] T038 [P] [US3] Добавить в `app/test/widget/diary_page_test.dart` проверки: при открытии ни один день не раскрыт, раскрытие второго дня не сворачивает первый, «реплик не было» вместо пустого блока, реплика персонажа вне каталога показывается по `characterId`. Задать `tester.view.physicalSize` с `addTearDown`-сбросом (lessons-learned: промах тапа на вьюпорте 800×600)

### Implementation for User Story 3

- [X] T039 [US3] Загружать `CharacterCatalog.load()` в `DiaryCubit.load()` (`app/lib/presentation/diary/cubit/diary_cubit.dart`) и класть `Map<String, Character>` в `DiaryData.characters`; отказ каталога деградирует до пустой карты, не до ошибки экрана (research.md R8)
- [X] T040 [US3] Реализовать `DiaryCubit.toggleDay(int entryId)` в `app/lib/presentation/diary/cubit/diary_cubit.dart`: инверсия `expanded` одного дня, ленивая загрузка `reactionsFor(entryId)` при первом раскрытии, кэш в `DiaryDay.reactions`, ошибка догрузки — в поток `failures`, не в состояние экрана (research.md R7)
- [X] T041 [P] [US3] Создать `app/lib/presentation/diary/widgets/diary_reactions_list.dart`: все сохранённые варианты в порядке `createdAt ASC` включая переспросы (FR-015), подпись именем персонажа с откатом на `characterId` (FR-019), иконка для `isFallback` тем же способом, что на Столе, и в описании для программ чтения (FR-017), явное «реплик не было» (FR-018)
- [X] T042 [US3] Дополнить `app/lib/presentation/diary/widgets/diary_day_card.dart`: одно раскрытие на карточку — тот же жест показывает полный текст дня и блок реплик (Clarifications, checklist review), тап-таргет ≥ `AppConstants.minTapTargetDp`, объявление «раскрыто/свёрнуто» для программ чтения
- [X] T043 [US3] Пробросить `toggleDay` и `DiaryData.characters` из `app/lib/presentation/diary/diary_page.dart` в `diary_day_card.dart`

**Checkpoint**: US1–US3 работают независимо

---

## Phase 6: User Story 4 — Экспортировать историю (Priority: P4)

**Goal**: полная сохранённая история в CSV через тот же системный «поделиться», что и шаринг реплики
на Столе, без сети и без подвисания интерфейса.

**Independent Test**: при непустой истории нажать «экспорт» в авиарежиме → открывается системный
диалог с файлом `roundtablezoo-<дата>.csv`, в котором корректные данные и корректное экранирование;
на пустой истории кнопка заблокирована.

### Tests for User Story 4 ⚠️

- [X] T044 [P] [US4] Создать `app/test/domain/export_diary_to_csv_test.dart`: строка заголовка, `date` из `DiaryDayEntry.day`, день с N репликами → N строк, день без реплик → одна строка с пустыми хвостовыми полями, экранирование `,`/`"`/переноса строки, `dayText == null` → пустое поле (а не текст `null`), пустая история → `ValidationFailure`, обход всей истории по `nextCursor` до `hasMore == false` (contracts/csv-export.md)
- [X] T045 [P] [US4] Добавить в `app/test/data/diary_repository_test.dart` тесты `reactionsForEntries`: группировка по `dayEntryId`, порядок `createdAt ASC`, записи без реплик отсутствуют в карте, пустой вход → пустая карта без обращения к БД
- [X] T046 [P] [US4] Добавить в `app/test/presentation/diary_cubit_test.dart` сценарии 13–15: на пустой истории `ShareService` не вызывается, успешный экспорт зовёт `shareCsv` один раз и снимает `exporting`, провал usecase → событие в `failures` при сохранении состояния `loaded`

### Implementation for User Story 4

- [X] T047 [US4] Добавить в `app/lib/data/datasources/diary_local_datasource.dart` метод `reactionsForEntryIds(List<int> ids)` — один запрос `WHERE dayEntryId IN (...)`, порядок `createdAt ASC`
- [X] T048 [US4] Объявить `reactionsForEntries(List<int>)` в `app/lib/domain/repositories/diary_repository.dart` и реализовать в `app/lib/data/repositories/diary_repository_impl.dart` (возврат `Map<int, List<CharacterReaction>>`, пустой вход без обращения к БД)
- [X] T049 [P] [US4] Реализовать `reactionsForEntries` в `UnavailableDiaryRepository` (`app/lib/data/repositories/read_only_repositories.dart`) → `storageReadOnly`
- [X] T050 [US4] Создать `app/lib/domain/usecases/export_diary_to_csv.dart`: единственная зависимость — `DiaryRepository`; обход истории страницами по `diaryExportBatchSize` через `entriesPage` + `DiaryPage.nextCursor`, батч-реплики через `reactionsForEntries`, накопление в `StringBuffer` с уступкой event loop между страницами, экранирование по RFC 4180, `date` из `DiaryDayEntry.day.toString()` — день уже вычислен репозиторием, `DayResolver` и `AppClock` usecase не нужны (research.md R9, R11; contracts/csv-export.md §1)
- [X] T051 [US4] Зарегистрировать `ExportDiaryToCsv` в `app/lib/core/di/injection_module.dart`
- [X] T052 [P] [US4] Добавить `shareCsv(String csv, {required String fileName})` в `ShareService` и `SharePlusShareService` (`app/lib/core/sharing/share_service.dart`) через `XFile.fromData(utf8.encode(csv), mimeType: 'text/csv')` + `fileNameOverrides` (research.md R10)
- [X] T053 [P] [US4] Добавить заглушку `shareCsv` в подменяемый `MockShareService` в `app/test/support/test_app_root.dart`, чтобы существующие widget-тесты не падали
- [X] T054 [US4] Добавить `ExportDiaryToCsv`, `ShareService` и `AppClock` в конструктор `DiaryCubit` и в его регистрацию в `app/lib/core/di/injection_module.dart` (в фазе Foundational их намеренно не было — T006), затем реализовать `DiaryCubit.export()` в `app/lib/presentation/diary/cubit/diary_cubit.dart`: `exporting: true` → usecase → `ShareService.shareCsv` с именем `roundtablezoo-<yyyy-MM-dd>` по времени из `AppClock` → `exporting: false`; отмена системного диалога не считается ошибкой (research.md R19)
- [X] T055 [US4] Добавить кнопку «экспорт» в `app/lib/presentation/diary/diary_page.dart`: видима и заблокирована при `!canExport` (не скрыта), тап-таргет ≥48dp, подпись `Semantics` (FR-024, FR-030, research.md R19)

**Checkpoint**: все четыре истории работают независимо

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: доступность, устойчивость вёрстки и гейты завершения задачи

- [X] T056 [P] Создать `app/test/widget/diary_accessibility_test.dart`: `meetsGuideline(androidTapTargetGuideline)` и `meetsGuideline(labeledTapTargetGuideline)` на списке с раскрытым днём и активной кнопкой экспорта (FR-030, SC-006)
- [X] T057 [P] Добавить в `app/test/widget/diary_accessibility_test.dart` проверку карточки дня при `TextScaler.linear(2)` — вёрстка не ломается, управляющие элементы не обрезаются (research.md R19, Edge Cases)
- [X] T058 [P] Проверить покрытие `DiaryCubit` через `flutter test --coverage` в `app/` — не ниже 70% (конституция §VI)
- [X] T059 Прогнать `flutter analyze` в `app/` без ошибок и `flutter test` полностью зелёным (конституция §Рабочий процесс п.5 — задача с падающими тестами не считается выполненной)
- [ ] T060 Пройти сценарии A–F из `specs/005-diary-screen/quickstart.md` на реальном среднем Android-устройстве, включая авиарежим, режим «только чтение» и историю ≈365 дней; замерить SC-001 (первая страница ≤2 с), SC-005 (экспорт ≤3 с) и SC-008 (следующая страница ≤1 с, 10 подгрузок подряд без дублей)
- [X] T061 [P] Создать `app/test/presentation/mood_score_invariant_test.dart` — сквозная проверка FR-011/SC-007: день с несколькими репликами разного `tone` и `intensity` → точка графика, значение в списке и `moodScore` в строке CSV равны сохранённому `moodScore`; изменение тона реплик не меняет ни одно из трёх
- [X] T062 Дописать в `project/process/lessons-learned.md` реальные грабли этой фазы, если они были (только то, что действительно потребовало переписывания, — гипотетические уроки туда не пишутся)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: без зависимостей, стартует сразу
- **Foundational (Phase 2)**: после Setup — **блокирует все истории**
- **US1 (Phase 3)**: после Foundational
- **US2 (Phase 4)**: после Foundational; при работе в одиночку удобнее после US1 (`diary_page.dart` общий)
- **US3 (Phase 5)**: после Foundational; трогает `diary_day_card.dart`, созданный в US1
- **US4 (Phase 6)**: после Foundational; переиспользует `entriesPage` из US1
- **Polish (Phase 7)**: после всех желаемых историй

### User Story Dependencies

- **US1 (P1)** — самостоятельна, ничего не ждёт кроме Foundational. Это MVP.
- **US2 (P2)** — самостоятельна по данным (`moodHistory` не пересекается с `entriesPage`); при
  параллельной работе конфликтует с US1 за `diary_page.dart` (T036 против T025) и `diary_cubit.dart`
  (T035 против T019).
- **US3 (P3)** — самостоятельна по данным (`reactionsFor` уже существует); дополняет
  `diary_day_card.dart` из US1 (T042 против T022) и `diary_cubit.dart` (T039/T040), поэтому в
  одиночной работе идёт после US1.
- **US4 (P4)** — переиспользует `entriesPage` (T016/T017 из US1). Если US4 делается раньше US1,
  T016/T017 надо забрать в неё; в приоритетном порядке этого не требуется.

**Самый нагруженный общий файл — `app/lib/presentation/diary/cubit/diary_cubit.dart`**: его правят
T019/T020/T021 (US1), T035 (US2), T039/T040 (US3) и T054 (US4). При параллельной работе он
сериализует истории независимо от того, что по данным они не пересекаются.

### Within Each User Story

- Тесты пишутся до реализации и должны падать до неё
- Datasource → репозиторий → Cubit → виджеты → сборка страницы
- Сущности (`MoodChartPoint`) до маппера, маппер до репозитория
- История завершена и проверена до перехода к следующей

### Parallel Opportunities

- T002 и T003 в Setup — разные файлы
- T018, T032, T049 (`read_only_repositories.dart`) — по одной на историю, между собой не пересекаются, но с задачами того же файла в других фазах не параллелятся
- Все тестовые задачи внутри истории (T012–T014, T026–T027, T037–T038, T044–T046) — разные файлы
- Виджеты US1 (T022, T023, T024) — три разных файла
- T056, T057, T058 в Polish — независимы
- При работе командой: после Foundational US1/US2/US4 берутся тремя разработчиками, US3 — после US1

---

## Parallel Example: User Story 1

```bash
# Тесты US1 — три разных файла, запускаются вместе:
Task: "Тесты entriesPage в app/test/data/diary_repository_test.dart"
Task: "Тесты DiaryCubit в app/test/presentation/diary_cubit_test.dart"
Task: "Widget-тесты списка в app/test/widget/diary_page_test.dart"

# Виджеты US1 — три разных файла:
Task: "diary_day_card.dart"
Task: "diary_empty_view.dart"
Task: "diary_error_view.dart"
```

---

## Implementation Strategy

### MVP First (только US1)

1. Phase 1: Setup (T001–T004)
2. Phase 2: Foundational (T005–T011) — блокирует всё
3. Phase 3: US1 (T012–T025)
4. **STOP и проверить**: сценарий B из quickstart.md — список, пагинация, пустое состояние, офлайн
5. На этом Дневник уже осмысленно заменяет заглушку и его можно показывать

### Incremental Delivery

1. Setup + Foundational → каркас готов
2. + US1 → список истории (MVP, демонстрируемо)
3. + US2 → график тренда
4. + US3 → реплики зверей в ретроспективе
5. + US4 → экспорт CSV
6. + Polish → доступность и гейты завершения

Каждая история добавляет ценность, не ломая предыдущие.

---

## Notes

- `dart run build_runner build --delete-conflicting-outputs` обязателен после каждой правки
  `@freezed`/`@injectable`/Drift-таблиц (T005, T007, T010, T028, T051, T054)
- Каждый widget-тест на `buildTestAppRoot()` обязан заканчиваться `disposeTestAppRoot(tester)` —
  `DiaryCubit` подписан на реальный Drift `watch()` (lessons-learned)
- Моки — только `mocktail`; `MockDiaryRepository`, `MockCharacterCatalog`, `MockShareService` уже
  есть в `app/test/support/mocks.dart`
- Схема БД не меняется, `schemaVersion` не поднимается, миграции не пишутся
- `[P]` = разные файлы без зависимостей; коммит после каждой задачи или логической группы
