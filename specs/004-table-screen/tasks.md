---

description: "Task list for feature implementation: Экран «Стол»"
---

# Tasks: Экран «Стол»

**Input**: Design documents from `/specs/004-table-screen/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: включены — этого требуют SC-011 (покрытие >70%) и принцип VI конституции
(`bloc_test` на каждый новый Cubit, моки только `mocktail`).

**Organization**: задачи сгруппированы по пользовательским историям спеки, чтобы каждую можно было
довести и проверить отдельно.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: можно выполнять параллельно (разные файлы, нет зависимостей от незавершённых задач)
- **[Story]**: US1..US5 — соответствие историям спеки
- Пути указаны от корня репозитория; команды выполняются из `app/`

## Path Conventions

Мобильное приложение со слоистой архитектурой: `app/lib/{core,domain,data,presentation}/`,
тесты — `app/test/{core,data,presentation,widget,support}/`. Раскладка — раздел «Project Structure»
в `plan.md`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: зависимости, ассеты и константы, без которых не начинается ни одна история

- [ ] T001 Добавить зависимости `dio` и `share_plus` в `app/pubspec.yaml`, выполнить `flutter pub get`, зафиксировать версии в `app/pubspec.lock` (research.md R1, R3)
- [ ] T002 Сверить API `share_plus` установленной версии с исходником в `~/.pub-cache/hosted/pub.dev/share_plus-<версия>/lib/share_plus.dart` и записать вывод (`Share.share` vs `SharePlus.instance.share`) в комментарий к `app/lib/core/sharing/share_service.dart` при его создании (research.md R3)
- [ ] T003 Объявить каталог ассетов `assets/characters/` в секции `flutter.assets` файла `app/pubspec.yaml`
- [ ] T004 [P] Создать ассет `app/assets/characters/characters.json` с четырьмя персонажами MVP (`cat`, `dog`, `crocodile`, `hippo`) по схеме `contracts/character-config.md` §1–2
- [ ] T005 [P] Добавить в `app/lib/core/constants/app_constants.dart` константы `aiRequestTimeout` (15 с, FR-027a), `dayTextAutosaveDebounce` (1 с, FR-008a), `speakingBubbleMaxDuration` (4 с, FR-017b), `maxCharactersAtTable` (6, FR-010a)
- [ ] T006 [P] Создать `app/lib/core/constants/mood_scale.dart` — маппинг `MoodScore.value` 1..5 → эмодзи, семантический цвет и ключ локализованной подписи (research.md R15, FR-001)
- [ ] T007 Создать `app/lib/core/network/ai_proxy_config.dart`: чтение `PROXY_BASE_URL` через `String.fromEnvironment`, признак «сконфигурирован», и падение с внятной ошибкой при пустом значении в release-сборке (research.md R2, SC-012)
- [ ] T008 Прогнать `flutter analyze` и `flutter test` — убедиться, что база зелёная до начала работ

**Checkpoint**: зависимости и конфигурация на месте, существующие тесты не сломаны

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: ошибки, доменные типы, каталог персонажей, строки локализации и тестовая обвязка —
всё, на что опирается любая история

**⚠️ CRITICAL**: ни одна история не начинается, пока эта фаза не завершена

- [ ] T009 Добавить `AiProxyFailure extends AppFailure` в `app/lib/core/errors/app_failure.dart` с кодами `network`, `rateLimited`, `aiDisabled`, `invalidResponse`, `timeout` и `localizedMessage` по образцу `DatabaseFailure` (research.md R7, FR-024–FR-027b)
- [ ] T010 [P] Создать `app/lib/domain/entities/character.dart` — Freezed-сущность по `data-model.md` §2 (`id`, `name`, `colorHex`, `idleAnimation?`, `talkAnimation?`, `fallbackReply`, `maxReplyLength`)
- [ ] T011 [P] Добавить новые ключи локализации в `app/lib/l10n/intl_ru.arb`, `intl_en.arb`, `intl_uk.arb`: подписи шкалы, плейсхолдер и счётчик поля текста, состояния персонажа, подсказки FR-014a, тексты `aiNetwork`/`aiRateLimited`/`aiTemporarilyDisabled`, пометки «на прежний текст» и «ответ по памяти», подпись действия «поделиться» (research.md R16)
- [ ] T012 Дополнить строку `onboardingAiDisclosure` во всех трёх ARB упоминанием анонимного идентификатора установки, уходящего вместе с текстом (FR-034a)
- [ ] T013 Создать `app/lib/data/datasources/character_catalog.dart` — загрузка `assets/characters/characters.json` через `rootBundle`, кэш на сессию, `Result<List<Character>>`, `SerializationFailure` при нарушении схемы (research.md R4, contracts/character-config.md §3)
- [ ] T014 [P] Написать `app/test/data/character_catalog_test.dart`: корректный разбор, отсутствие обязательного поля, дубль `id`, пустой массив, неизвестные поля игнорируются
- [ ] T015 Зарегистрировать `CharacterCatalog` и `AiProxyClient` (боевой/заглушка по `AiProxyConfig`) в `app/lib/core/di/injection_module.dart`
- [ ] T016 Выполнить `dart run build_runner build --delete-conflicting-outputs` и `flutter gen-l10n`, убедиться в отсутствии ошибок кодогенерации
- [ ] T017 Обновить `app/test/support/test_app_root.dart`: пересоздавать `CurrentDayCubit` на каждый `buildTestAppRoot()` тем же приёмом, что уже применён к `AppSettingsCubit` (research.md R13, `project/process/lessons-learned.md`)
- [ ] T018 [P] Добавить в `app/test/support/mocks.dart` моки `AiReactionRepository`, `CharacterCatalog`, `ShareService` на `mocktail`
- [ ] T019 Подменять `ShareService` на мок в `app/test/support/test_app_root.dart`, чтобы widget-тесты не уходили в платформенный канал (урок про `MissingPluginException`)
- [x] T020a Публиковать текущий `StorageMode` в `app/lib/core/di/storage_di_switch.dart` в обеих ветках (`usePersistentStorage` → `persistent`, `useReadOnlyStorage` → `readOnly`) со снятием прежней регистрации; `unavailable` не регистрируется (research.md R12, FR-032) — **выполнено при `/speckit-analyze`**, `flutter analyze` без ошибок, 163 теста зелёные
- [ ] T020b Регистрировать `StorageMode.persistent` в `app/test/support/test_app_root.dart` рядом с пересозданием `CurrentDayCubit` — иначе widget-тесты на `/table` упадут с `GetIt: StorageMode is not registered` (`project/process/lessons-learned.md`)
- [ ] T020 Прогнать `flutter analyze` и `flutter test` — фундамент не ломает существующие тесты

**Checkpoint**: доменные типы, ошибки, каталог и тестовая обвязка готовы — можно начинать истории

---

## Phase 3: User Story 1 — Отметить настроение за сегодня (Priority: P1) 🎯 MVP

**Goal**: пользователь открывает Стол, выбирает эмодзи, отметка сохраняется в запись дня и
восстанавливается при повторном входе — полностью офлайн

**Independent Test**: в авиарежиме открыть Стол → выбрать эмодзи → перезапустить приложение →
значение на месте; в Дневнике день появился

### Tests for User Story 1

- [ ] T021 [P] [US1] Написать `app/test/presentation/table_cubit_test.dart` — блок US1: `load()` на пустом дне, `load()` с существующей записью, `setMood` создаёт запись, `setMood` обновляет существующую, отказ репозитория уходит в `failures` без смены состояния, `readOnly` не вызывает репозиторий, `setMood` не затирает сохранённый `dayText` и не меняется от правки текста (FR-009, contracts/table-cubit.md §4)
- [ ] T022 [P] [US1] Написать `app/test/widget/table_page_test.dart` — блок US1: шкала из 5 вариантов, выбор выделен, восстановление сохранённой оценки, баннер и сообщение в режиме только чтения; последней строкой каждого теста — `disposeTestAppRoot(tester)`

### Implementation for User Story 1

- [ ] T023 [US1] Создать `app/lib/presentation/table/cubit/table_state.dart` — Freezed sealed `initial/loading/loaded/error` и `TableData` по `data-model.md` §3 (без полей реакций на этом шаге)
- [ ] T024 [US1] Создать `app/lib/presentation/table/cubit/table_cubit.dart` — конструктор по `contracts/table-cubit.md` §1, методы `load()` и `setMood()`, поток `failures`, `StorageMode` для `readOnly` (research.md R12)
- [ ] T025 [US1] Зарегистрировать `TableCubit` как `@injectable` factory в `app/lib/core/di/injection_module.dart` (research.md R5 — экранный, не `lazySingleton`)
- [ ] T026 [P] [US1] Создать `app/lib/presentation/table/widgets/mood_scale_row.dart` — пять вариантов из `mood_scale.dart`, выбранный выделен формой и цветом, тап-таргет ≥`AppConstants.minTapTargetDp`, `Semantics` с подписью и состоянием (FR-001, FR-013)
- [ ] T027 [US1] Создать `app/lib/presentation/table/table_page.dart` — `BlocProvider` через `getIt`, `state.when` с общими состояниями загрузки/ошибки, inline-подача ошибок из `failures` (FR-006b, FR-029)
- [ ] T028 [US1] Заменить `TablePlaceholderPage` на `TablePage` в `app/lib/app/router/app_router.dart` и удалить `app/lib/presentation/table/table_placeholder_page.dart`
- [ ] T029 [US1] Реализовать поведение режима «только чтение» в `TableCubit`/`TablePage`: сохранение не вызывается, показывается объяснение, баннер рисует существующий `ShellPage` (FR-032)
- [ ] T030 [US1] Прогнать `flutter analyze` и `flutter test`, затем ручной прогон шагов US1 из `quickstart.md` §2 и §5

**Checkpoint**: офлайн-ядро поставлено — приложение уже полезно как трекер настроения

---

## Phase 4: User Story 2 — Рассказать о дне и услышать зверя (Priority: P2)

**Goal**: пользователь пишет текст дня (с автосохранением) и получает реплику зверя по тапу;
реплика сохраняется к записи дня

**Independent Test**: ввести текст, тапнуть по зверю, увидеть реплику в бабле; найти её в Дневнике
у сегодняшнего дня

### Tests for User Story 2

- [ ] T031 [P] [US2] Дополнить `app/test/presentation/table_cubit_test.dart` блоком текста: дебаунс через `fake_async` (одно сохранение на серию правок), `flushDayText` из `close()` **и по `AppLifecycleState.paused`** (SC-009), текст до выбора эмодзи уходит первым `setMood` (FR-008a–FR-008c)
- [ ] T032 [P] [US2] Дополнить `app/test/presentation/table_cubit_test.dart` блоком реакции: успешный ответ сохраняется и попадает в слот, предусловия FR-014 (нет настроения / пустой текст / `readOnly`) не отправляют запрос, отказ `addReaction` даёт `persistFailed` (FR-021c)
- [ ] T033 [P] [US2] Написать `app/test/data/ai_reaction_repository_test.dart` — разбор успешного ответа по `contracts/ai-proxy-client.md` §3: несовпадение `character`, неизвестный `mood` → `neutral`, отсутствующая `intensity` → 0.5, пустой `reply` → `invalidResponse`
- [ ] T034 [P] [US2] Дополнить `app/test/widget/table_page_test.dart`: поле текста со счётчиком и лимитом 2000, недоступность тапа по зверю без текста с видимой подсказкой, появление бабла после ответа

### Implementation for User Story 2

- [ ] T035 [P] [US2] Создать `app/lib/data/models/ai_reaction_dto.dart` — `@JsonSerializable` по `contracts/ai-proxy-client.md` §3
- [ ] T036 [P] [US2] Создать `app/lib/domain/repositories/ai_reaction_repository.dart` — интерфейс из `contracts/ai-proxy-client.md` §5
- [ ] T037 [US2] Создать `app/lib/core/network/ai_proxy_client.dart` — интерфейс `AiProxyClient` и `DioAiProxyClient` с базовым URL из `AiProxyConfig`, таймаутами 10/15 с, без интерцептора подлинности (research.md R1, FR-016a)
- [ ] T038 [P] [US2] Создать `app/lib/core/network/stub_ai_proxy_client.dart` — детерминированные реплики на персонажа (четыре зверя дают четыре различающиеся реплики на один текст — SC-003a), задержка ~1.2 с, управляемый сценарий отказа по образцу `DebugFailureInjector` (contracts/ai-proxy-client.md §6)
- [ ] T039 [US2] Создать `app/lib/data/repositories/ai_reaction_repository_impl.dart` — единственное место маппинга HTTP/`DioException` → `AiProxyFailure`, правила разбора §3, логирование только кода отказа и `characterId` (FR-034b)
- [ ] T040 [US2] Зарегистрировать `AiReactionRepository` в `app/lib/core/di/injection_module.dart`
- [ ] T041 [US2] Расширить `TableData`/`CharacterSlot` в `app/lib/presentation/table/cubit/table_state.dart` полями по `data-model.md` §3 (`slots`, `characters`, `isDayTextDirty`)
- [ ] T042 [US2] Реализовать в `app/lib/presentation/table/cubit/table_cubit.dart` работу с текстом: `onDayTextChanged` с дебаунсом, `flushDayText` (из `close()`, `paused`, перед запросом), сохранение текста, набранного до выбора эмодзи (FR-008a–FR-008c, FR-006a)
- [ ] T043 [US2] Реализовать `requestReaction` в `app/lib/presentation/table/cubit/table_cubit.dart` без гонок (базовый путь: предусловия → `loading` → ответ → `addReaction` → `spoken`); generation-счётчик добавляется в US3
- [ ] T044 [P] [US2] Создать `app/lib/presentation/table/widgets/day_text_field.dart` — поле с лимитом `AppConstants.maxDayTextLength`, счётчиком, вызовом `onDayTextChanged` (FR-007, FR-008)
- [ ] T045a [US2] Фильтровать каталог по `enabledCharacterIds` и подписываться на `SettingsRepository.watch()` в `app/lib/presentation/table/cubit/table_cubit.dart`: состав стола обновляется без перезахода, выключенный персонаж исчезает вместе с баблом, его реакции остаются в хранилище (FR-010, FR-010c)
- [ ] T045 [P] [US2] Создать `app/lib/presentation/table/widgets/round_table_layout.dart` — `LayoutBuilder` + `Stack` с тригонометрией, 1..6 персонажей, порядок из каталога (research.md R9, FR-010a)
- [ ] T046 [P] [US2] Создать `app/lib/presentation/table/widgets/character_avatar.dart` — четыре состояния, Lottie при наличии ассета и статичный аватар при его отсутствии, `Semantics(button: true, label: '<имя>, <состояние>')`, тап-таргет ≥48dp (FR-010e, FR-011, FR-012, FR-013)
- [ ] T047 [P] [US2] Создать `app/lib/presentation/table/widgets/speaking_bubble.dart` — эффект проговаривания через `AnimationController` с верхней границей 4 с, мгновенный показ при `MediaQuery.disableAnimationsOf` (research.md R8, FR-017, FR-017b, FR-033a)
- [ ] T048 [US2] Собрать экран в `app/lib/presentation/table/table_page.dart`: шкала + поле текста + круглый стол + баблы, состояние ожидания сразу по тапу (FR-016), подсказки FR-014a
- [ ] T049 [US2] Прогнать `flutter analyze`, `flutter test`, затем ручной прогон US2 из `quickstart.md` §2 на заглушке

**Checkpoint**: US1 и US2 работают независимо — стол отвечает, реплики сохраняются

---

## Phase 5: User Story 3 — Переспросить и сравнить зверей (Priority: P3)

**Goal**: повторные и параллельные тапы дают предсказуемый результат, реплики переживают
перезаход и правку текста

**Independent Test**: тапнуть по зверю дважды подряд, не дожидаясь первого ответа — остаётся
результат последнего тапа; уйти с экрана и вернуться — реплики на месте

### Tests for User Story 3

- [ ] T050 [P] [US3] Дополнить `app/test/presentation/table_cubit_test.dart`: два тапа по одному персонажу (побеждает последний, устаревший ответ не вызывает `addReaction`), параллельные тапы по двум персонажам, `isClosed` после `await`, три переспроса одного персонажа дают три сохранённых реакции при одной показанной (contracts/table-cubit.md §3, FR-019, FR-020, FR-021a, FR-021b, FR-021d)
- [ ] T051 [P] [US3] Дополнить `app/test/presentation/table_cubit_test.dart`: восстановление последней реплики на персонажа при `load()`, `restored: true`, отсутствие сетевых вызовов; пометка `stale` при правке текста и её снятие новым ответом; день с двумя записями (после смены пояса) — экран и новые реакции относятся к самой поздней (FR-003a, FR-005, FR-023, FR-023a)
- [ ] T052 [P] [US3] Дополнить `app/test/presentation/table_cubit_test.dart`: `onDayChanged` сбрасывает состояние, перезагружает день и записывает несохранённый текст в **уходящий** день (FR-006, FR-006a)

### Implementation for User Story 3

- [ ] T053 [US3] Добавить generation-счётчик в `app/lib/presentation/table/cubit/table_cubit.dart` в порядке «`isClosed` → сверка поколения → `emit`/`addReaction`» (research.md R6, FR-020)
- [ ] T054 [US3] Реализовать восстановление реплик в `load()`: `entryForDay` → `reactionsFor` → последняя по `createdAt` на персонажа, `restored: true`, пропуск неизвестных `characterId` (research.md R11, FR-003a, FR-003b)
- [ ] T055 [US3] Реализовать пометку `stale` при правке текста и её снятие новым ответом в `app/lib/presentation/table/cubit/table_cubit.dart` (FR-023, FR-023a, FR-023b)
- [ ] T056 [US3] Отобразить пометку «на прежний текст» в `app/lib/presentation/table/widgets/speaking_bubble.dart` — визуально и в семантике (FR-023)
- [ ] T057 [US3] Подключить `BlocListener<CurrentDayCubit, CurrentDayState>` в `app/lib/presentation/table/table_page.dart` с вызовом `TableCubit.onDayChanged` (research.md R13, FR-006); смена состава персонажей — обязанность T045a, здесь не дублируется
- [ ] T058 [US3] Показывать восстановленные реплики сразу целиком, без эффекта проговаривания, в `app/lib/presentation/table/widgets/speaking_bubble.dart` (FR-003b)
- [ ] T059 [US3] Прогнать `flutter analyze`, `flutter test`, ручной прогон соответствующих строк `quickstart.md` §2

**Checkpoint**: гонки тапов, восстановление и смена дня ведут себя предсказуемо

---

## Phase 6: User Story 4 — Понятное поведение, когда AI недоступен (Priority: P4)

**Goal**: пять отказов дают пять заданных результатов, приложение не падает, отметка настроения
продолжает работать

**Independent Test**: последовательно смоделировать `network`, `rateLimited`, `aiDisabled`,
`invalidResponse`, `timeout` и сверить с таблицей `quickstart.md` §3

### Tests for User Story 4

- [ ] T060 [P] [US4] Дополнить `app/test/data/ai_reaction_repository_test.dart`: маппинг `429`/`503`/`422`/прочих статусов и типов `DioException` в коды `AiProxyFailure` (contracts/ai-proxy-client.md §4)
- [ ] T061 [P] [US4] Дополнить `app/test/presentation/table_cubit_test.dart`: `invalidResponse` и `timeout` дают заготовленную реплику с `isFallback: true`; `network`/`rateLimited`/`aiDisabled` возвращают слот в состояние до тапа и публикуют сигнал в `failures` — включая случай «у персонажа уже была реплика» (FR-027, FR-027b, FR-029a)
- [ ] T062 [P] [US4] Дополнить `app/test/widget/table_page_test.dart`: три текста ошибок различимы и показываются inline, шкала настроения остаётся рабочей при каждом отказе (FR-024–FR-026, FR-028)

### Implementation for User Story 4

- [ ] T063 [US4] Реализовать таймаут запроса 15 с в `app/lib/core/network/ai_proxy_client.dart` и его маппинг в `AiProxyFailure(timeout)` в `app/lib/data/repositories/ai_reaction_repository_impl.dart` (FR-027a, FR-027b)
- [ ] T064 [US4] Реализовать ветку fallback в `app/lib/presentation/table/cubit/table_cubit.dart`: заготовленная реплика персонажа из каталога сохраняется через `addReaction` с `isFallback: true` (FR-021, FR-027)
- [ ] T065 [US4] Реализовать возврат слота в состояние до тапа и публикацию сигнала для `network`/`rateLimited`/`aiDisabled` в `app/lib/presentation/table/cubit/table_cubit.dart` (FR-029a, FR-029b)
- [ ] T066 [US4] Отобразить пометку «ответ по памяти» у заготовленной реплики в `app/lib/presentation/table/widgets/speaking_bubble.dart` — ненавязчиво, не как ошибка, с отражением в семантике (FR-027c)
- [ ] T067 [US4] Показывать сообщение о несохранённой реплике при `persistFailed` в `app/lib/presentation/table/table_page.dart` (FR-021c)
- [ ] T068 [US4] Прогнать `flutter analyze`, `flutter test`, ручной прогон всех пяти отказов из `quickstart.md` §3 и офлайн-проверки §5

**Checkpoint**: демонстрация не ломается ни при одном отказе сервиса

---

## Phase 7: User Story 5 — Поделиться репликой (Priority: P5)

**Goal**: реплику можно отправить через системный диалог

**Independent Test**: получить реплику, вызвать «поделиться», увидеть системный лист с текстом и
именем персонажа

### Tests for User Story 5

- [ ] T069 [P] [US5] Написать проверку в `app/test/widget/table_page_test.dart`: долгое нажатие по баблу вызывает `ShareService` с текстом реплики и именем персонажа (мок из `test/support/mocks.dart`), короткий тап — не вызывает

### Implementation for User Story 5

- [ ] T070 [P] [US5] Создать `app/lib/core/sharing/share_service.dart` — интерфейс `ShareService` и реализация поверх `share_plus` (API — по результату T002), регистрация в `injection_module.dart` (research.md R3)
- [ ] T071 [US5] Развести жесты в `app/lib/presentation/table/widgets/speaking_bubble.dart`: короткий тап раскрывает реплику целиком, долгое нажатие делится (FR-017a, FR-030)
- [ ] T072 [US5] Добавить именованное действие «поделиться» в семантику бабла в `app/lib/presentation/table/widgets/speaking_bubble.dart`, чтобы жест не был единственным способом (FR-030)
- [ ] T073 [US5] Прогнать `flutter analyze`, `flutter test`, ручной прогон строки «поделиться» из `quickstart.md` §2

**Checkpoint**: все пять историй работают

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: доступность, производительность, приватность и завершение задачи по правилам проекта

- [ ] T074 [P] Написать `app/test/widget/table_accessibility_test.dart`: `meetsGuideline(labeledTapTargetGuideline)`, `meetsGuideline(androidTapTargetGuideline)`, наличие метки состояния у каждого персонажа (SC-008); флаги семантики сравнивать с `Tristate.isTrue`, а не с `bool` (`lessons-learned.md`)
- [ ] T075 [P] Реализовать явный порядок обхода фокусом в `app/lib/presentation/table/table_page.dart`: шкала → поле текста → персонажи по кругу → бабл активного (FR-035)
- [ ] T076 [P] Реализовать объявление новой реплики программе чтения с экрана в `app/lib/presentation/table/widgets/speaking_bubble.dart` (FR-036)
- [ ] T077 Проверить, что ни `dayText`, ни текст реплик не попадают в логи: пройтись по `app/lib/data/repositories/ai_reaction_repository_impl.dart`, `app/lib/core/network/ai_proxy_client.dart` и `AppLogger`-вызовам экрана (FR-034b)
- [ ] T078 Сверить список включённых по умолчанию персонажей между `app/assets/characters/characters.json`, `SettingsRepositoryImpl` и `ReadOnlySettingsRepository` (FR-010b)
- [ ] T079 Проверить поведение при отсутствующем/битом каталоге персонажей — временно испортив `app/assets/characters/characters.json`: стол пуст, шкала настроения работает (FR-010d)
- [ ] T080 Замерить на устройстве базового класса (Android 10+, 4 ГБ ОЗУ) на release-сборке по процедуре `quickstart.md` §7: средний темп ≥55 FPS и ни одного кадра дольше 100 мс за 60 секунд, индикация ожидания появляется ≤2 с после тапа, бабл наполняется ≤15 с (SC-006, SC-007, FR-033)
- [ ] T081 Проверить, что release-сборка с пустым `PROXY_BASE_URL` падает с внятной ошибкой, а не уходит на заглушку (SC-012)
- [ ] T082 Финальный gate: `flutter analyze` без ошибок и `flutter test` полностью зелёный; убедиться, что покрытие нового кода состояния не ниже 70% (SC-011)
- [ ] T083 Полный ручной прогон `quickstart.md` §2–§7
- [ ] T084 Записать в `project/process/lessons-learned.md` реальные грабли этой фазы (что сломалось → что делать вместо → почему это не разовая случайность); если ничего не ломалось — ничего не добавлять

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: без зависимостей
- **Foundational (Phase 2)**: после Setup — БЛОКИРУЕТ все истории
- **US1 (Phase 3)**: после Phase 2
- **US2 (Phase 4)**: после Phase 2; переиспользует экран и Cubit из US1
- **US3 (Phase 5)**: после US2 — уточняет поведение уже существующих запросов
- **US4 (Phase 6)**: после US2 — описывает отказы уже существующего пути
- **US5 (Phase 7)**: после US2 — надстройка над баблом
- **Polish (Phase 8)**: после всех нужных историй

### User Story Dependencies

- **US1 (P1)**: независима — единственная история, поставляемая без сети
- **US2 (P2)**: технически независима от US1 по коду сети и каталога, но её сценарий требует
  выбранного настроения (FR-014), поэтому демонстрируется поверх US1
- **US3 (P3)**: требует US2 (нечего переспрашивать без первого ответа)
- **US4 (P4)**: требует US2 (нечему отказывать)
- **US5 (P5)**: требует US2 (нечем делиться)

### Within Each User Story

- Тесты пишутся первыми и должны падать до реализации
- Сущности и DTO → репозитории/клиенты → Cubit → виджеты → сборка экрана
- Кодогенерация (`build_runner`, `gen-l10n`) — после правок Freezed/JSON/DI/ARB
- История считается закрытой только при зелёных `flutter analyze` и `flutter test`

### Parallel Opportunities

- Phase 1: T004, T005, T006 параллельны
- Phase 2: T010, T011 параллельны; T014, T018 параллельны после T013
- Phase 3: T021 и T022 параллельны; T026 параллелен T023–T025
- Phase 4: T031–T034 параллельны; T035, T036, T038 параллельны; виджеты T044–T047 параллельны
- Phase 5: T050–T052 параллельны
- Phase 6: T060–T062 параллельны
- Phase 8: T074–T076 параллельны
- Задачи, правящие один файл (`table_cubit.dart`, `table_state.dart`, `speaking_bubble.dart`,
  `injection_module.dart`), параллельными **не** помечены — это частый источник конфликтов

---

## Parallel Example: User Story 2

```bash
# Тесты US2 — вместе:
Task: "Дополнить app/test/presentation/table_cubit_test.dart блоком текста (T031)"
Task: "Дополнить app/test/presentation/table_cubit_test.dart блоком реакции (T032)"   # тот же файл — писать последовательно
Task: "Написать app/test/data/ai_reaction_repository_test.dart (T033)"
Task: "Дополнить app/test/widget/table_page_test.dart (T034)"

# Виджеты US2 — вместе:
Task: "Создать app/lib/presentation/table/widgets/day_text_field.dart (T044)"
Task: "Создать app/lib/presentation/table/widgets/round_table_layout.dart (T045)"
Task: "Создать app/lib/presentation/table/widgets/character_avatar.dart (T046)"
Task: "Создать app/lib/presentation/table/widgets/speaking_bubble.dart (T047)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup
2. Phase 2: Foundational
3. Phase 3: US1 — шкала настроения с сохранением
4. **Остановиться и проверить**: офлайн-прогон `quickstart.md` §5 + `flutter test`
5. На этом этапе приложение уже полезно: трекер настроения работает без сети и без AI

### Incremental Delivery

1. Setup + Foundational → фундамент
2. US1 → офлайн-ядро (MVP)
3. US2 → звери отвечают на заглушке
4. US3 → предсказуемость переспросов и восстановление
5. US4 → устойчивость к пяти отказам
6. US5 → шаринг
7. Polish → доступность, приватность, производительность

### Parallel Team Strategy

Проект ведёт один разработчик, поэтому параллелизм — внутри фазы (метки `[P]`), а не между
историями. При появлении второго человека после Phase 2 можно развести US2 (сеть и репозиторий) и
US1 (экран и шкала) — они трогают разные файлы, пересекаясь только в `table_cubit.dart`.

---

## Notes

- `[P]` = разные файлы, нет зависимостей
- После правок `@freezed`/`@injectable`/`@JsonSerializable`/ARB обязателен `build_runner`/`gen-l10n`
- Каждый widget-тест на `buildTestAppRoot()` обязан последней строкой звать `disposeTestAppRoot(tester)`
- Прокси в этот срез не входит: US2–US5 проверяются на `StubAiProxyClient`
- Коммит после каждой задачи или логической группы; задача с падающими тестами не считается сделанной
