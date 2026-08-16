---

description: "Task list for 003-onboarding"
---

# Tasks: Онбординг — первый запуск

**Input**: Design documents from `specs/003-onboarding/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/ui-contracts.md](./contracts/ui-contracts.md),
[quickstart.md](./quickstart.md)

**Tests**: включены. Не по запросу в спеке, а по конституции (принцип VI: `bloc_test` на каждый
новый Cubit, покрытие >70%, a11y-проверки) и по [quickstart.md](./quickstart.md), где состав
автотестов задан явно.

**Organization**: задачи сгруппированы по пользовательским историям; каждая история проверяема
независимо.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: можно выполнять параллельно (разные файлы, нет зависимостей)
- **[Story]**: US1 / US2 / US3 — привязка к историям из spec.md
- Пути указаны от корня репозитория

## Path Conventions

Мобильное приложение, один модуль: код — `app/lib/`, тесты — `app/test/`. Команды выполняются из
`app/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: тексты и каркас папки — без них не соберётся ни один экранный файл

- [X] T001 [P] Добавить ключи онбординга (`onboardingTitle`, `onboardingHowTo`, `onboardingDisclaimer`, `onboardingAiDisclosure`, `onboardingStart`) с описаниями в `app/lib/l10n/intl_ru.arb` (шаблонный файл), соблюдая FR-004a (≤2 предложения на пункт) и FR-004b (без формулировок согласия). `onboardingAiDisclosure` ДОЛЖЕН содержать все три смысловых элемента FR-004d: внешний AI-сервис третьей стороны, передаётся только текст о дне, настроение и дневник остаются на устройстве. Сверить формулировку с `project/architecture/backend-proxy.md` §8
- [X] T002 Перевести те же ключи в `app/lib/l10n/intl_en.arb` и `app/lib/l10n/intl_uk.arb`, сохранив смысл пунктов (b) и (c) без смягчения (FR-009b); проверить, что `app/lib/gen/untranslated_messages.json` не пополнился
- [X] T003 Создать каталог `app/lib/presentation/onboarding/cubit/` и `app/lib/presentation/onboarding/widgets/` под структуру из plan.md

**Checkpoint**: тексты доступны через `AppLocalizations`, структура папок готова

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: `OnboardingCubit` и его тестовая обвязка — от них зависят все три истории

**⚠️ CRITICAL**: ни одна история не начинается, пока эта фаза не завершена

- [X] T004 Создать `OnboardingState` (Freezed sealed: `unknown` / `required` / `submitting` / `completed`, без полей) в `app/lib/presentation/onboarding/cubit/onboarding_state.dart` по data-model.md
- [X] T005 Реализовать `OnboardingCubit` в `app/lib/presentation/onboarding/cubit/onboarding_cubit.dart`: конструктор `{required SettingsRepository Function() settingsRepositoryLocator, required OnboardingState initialState, Duration writeTimeout = defaultWriteTimeout}` (`defaultWriteTimeout = Duration(seconds: 3)` — параметр, а не константа, иначе тест таймаута ждёт три реальные секунды), методы `resolve()` и `complete()` по гарантиям **C1, C2, C5, C6, C8** (`contracts/ui-contracts.md`) — то есть FR-005 (переход только после завершения записи) и FR-006 (переход и при `Result.failure`); `isClosed`-guard после каждого `await`. Терминальность `completed` (C3, C4) и таймаут (C7) реализуются в US3 — T027, T028
- [X] T006 Выполнить `dart run build_runner build --delete-conflicting-outputs` в `app/` и убедиться, что `onboarding_state.freezed.dart` сгенерирован
- [X] T007 Зарегистрировать фабрику `OnboardingCubit` в `app/lib/core/di/injection_module.dart` с комментарием о ленивом резолве `SettingsRepository` (как у `currentDayCubit`)
- [X] T008 Добавить параметр `bool onboardingSeen = true` в `buildTestAppRoot()` (`app/test/support/test_app_root.dart`) и пересоздавать `OnboardingCubit` на каждый вызов через `getIt.unregister` + `registerLazySingleton` — по образцу `AppSettingsCubit`; в docstring сослаться на research.md R7 и на `project/process/lessons-learned.md`

**Checkpoint**: Cubit собирается, резолвится через DI, тестовый хелпер не ломает существующие тесты

---

## Phase 3: User Story 1 — Первый запуск показывает приветствие (Priority: P1) 🎯 MVP

**Goal**: на свежей установке пользователь видит экран онбординга, одним касанием попадает на стол,
и больше онбординг не появляется.

**Independent Test**: `buildTestAppRoot(onboardingSeen: false)` → виден экран онбординга, `NavigationBar`
отсутствует; тап по действию продолжения → появляется шелл. При `onboardingSeen: true` шелл виден
сразу.

### Tests for User Story 1

> Пишутся первыми и должны падать до реализации

- [X] T009 [P] [US1] `bloc_test` на `OnboardingCubit` в `app/test/presentation/onboarding_cubit_test.dart`: `required → submitting → completed` при успешной записи; `resolve()` из `unknown` даёт `required`/`completed` по значению флага (C1); `resolve()` при `Result.failure` от репозитория даёт `required`, а не `unknown` (C8, FR-001a); `resolve()` при недоступном локаторе оставляет `unknown` и не бросает (C5)
- [X] T010 [P] [US1] Widget-тест гейта в `app/test/widget/onboarding_gate_test.dart`: при `onboardingSeen: false` стартуем на онбординге без шелла; при `onboardingSeen: true` — сразу шелл; прямой `router.go('/onboarding')` при `onboardingSeen: true` оставляет пользователя на столе (FR-001, FR-002, FR-007, FR-007a, SC-001, C9)

### Implementation for User Story 1

- [X] T011 [US1] Создать `OnboardingPage` в `app/lib/presentation/onboarding/onboarding_page.dart`: заголовок, три пункта в порядке (a)→(b)→(c), единственное действие продолжения; тап вызывает `context.read<OnboardingCubit>().complete()`, навигацию инициирует редирект, а не сам экран (contracts §3)
- [X] T012 [P] [US1] Вынести три пункта в `app/lib/presentation/onboarding/widgets/onboarding_points.dart`, тексты — только из `AppLocalizations` (FR-004, FR-009)
- [X] T013 [US1] Добавить параметр `onboardingCubit` в `AppRoot` (`app/lib/app/app_root.dart`) и провайдить его через `BlocProvider.value` рядом с `storageRecoveryCubit`
- [X] T014 [US1] Расширить `buildAppRouter` в `app/lib/app/router/app_router.dart`: параметр `onboardingCubit`, правила редиректа 3 и 4 после storage-правил, `refreshListenable` как `Listenable.merge` двух `CubitRefreshListenable` (contracts §2, research.md R1)
- [X] T015 [US1] Заменить `OnboardingPlaceholderPage` на `OnboardingPage` в маршруте `/onboarding` и обновить устаревший комментарий «без redirect-гейта» в `app/lib/app/router/app_routes.dart`
- [X] T016 [US1] В `app/lib/main.dart` построить `OnboardingCubit` из уже загруженного снимка настроек в ветке `StorageMode.persistent` (`settings?.hasSeenOnboarding ?? false` → `completed`/`required`), в ветке `unavailable` — `unknown`; передать в `AppRoot` (research.md R2)
- [X] T017 [US1] Убедиться, что `_refreshListenable` и оба `CubitRefreshListenable` корректно освобождаются в `dispose()` `_RoutedAppState` (`app/lib/app/app_root.dart`)

**Checkpoint**: US1 работает целиком — гейт, экран, переход, отсутствие повторного показа

---

## Phase 4: User Story 2 — Один экран, одно касание (Priority: P2)

**Goal**: онбординг остаётся единственным шагом: всё видно без прокрутки при настройках по
умолчанию, действие активно сразу, «назад» ведёт себя как на корневом экране.

**Independent Test**: при настройках по умолчанию заголовок, все три пункта и кнопка видны без
прокрутки; на `/onboarding` `canPop()` возвращает `false`; кнопка активна с первого кадра.

### Tests for User Story 2

- [X] T018 [P] [US2] Тест «назад» в `app/test/widget/onboarding_gate_test.dart`: на `/onboarding` `router.canPop() == false` (FR-008, research.md R6)
- [X] T019 [P] [US2] Тест компоновки в `app/test/widget/onboarding_gate_test.dart`: при размере экрана по умолчанию и обычном шрифте заголовок, три пункта и действие продолжения находятся в дереве без прокрутки, а `Scrollable` не имеет смещения (FR-004a, FR-004c, SC-002, US2.3)
- [X] T020 [P] [US2] Тест запуска по уведомлению: переход на `/table` при `onboardingSeen: false` оставляет пользователя на онбординге (FR-002b, research.md R6a)

### Implementation for User Story 2

- [X] T021 [US2] Привести компоновку `OnboardingPage` к FR-004a/FR-010b: содержимое в прокручиваемом контейнере, но при настройках по умолчанию помещается целиком; действие продолжения не уезжает за пределы первого экрана
- [X] T022 [US2] Убрать из `OnboardingPage` любые навигационные элементы: у `Scaffold` нет `bottomNavigationBar`, у `AppBar` (если он есть) — `automaticallyImplyLeading: false` и никаких `actions`; ссылок на другие экраны нет (FR-003a)
- [X] T023 [US2] Привязать `onPressed` действия продолжения к состоянию: `null` только в `submitting`, во всех остальных — активен; проверить widget-тестом, что на первом кадре кнопка не `disabled` (FR-003, FR-005a)
- [X] T023a [P] [US2] Widget-тест языка и темы первого запуска в `app/test/widget/onboarding_gate_test.dart`: при `LocalePreference.system` и `ThemePreference.system` онбординг рендерится по общим правилам приложения (системный язык, RU-фолбэк для неподдерживаемого) — FR-009a

**Checkpoint**: US1 и US2 работают независимо; экран соответствует «одно касание, без стены онбординга»

---

## Phase 5: User Story 3 — Онбординг переживает прерывание (Priority: P3)

**Goal**: непройденный онбординг показывается снова после перезапуска; сбой, таймаут и аварийный
режим хранилища не запирают пользователя и не показывают онбординг дважды за сессию.

**Independent Test**: при `Result.failure` от `markOnboardingSeen()` пользователь всё равно попадает
на стол и в той же сессии онбординг не возвращается; в режиме read-only онбординг показывается, а
после подтверждения — нет.

### Tests for User Story 3

- [X] T024 [P] [US3] `bloc_test` в `app/test/presentation/onboarding_cubit_test.dart`: `completed` при `Result.failure` (C2); повторный `complete()` во время `submitting` не вызывает репозиторий второй раз (C3); `completed` не откатывается через `resolve()` (C4)
- [X] T025 [P] [US3] `bloc_test` на таймаут в `app/test/presentation/onboarding_cubit_test.dart`: Cubit конструируется с коротким `writeTimeout` (например, 20 мс), репозиторий не отвечает → состояние всё равно становится `completed` (C7, FR-005b, SC-003). Значение по умолчанию (3 с) в тестах не используется
- [X] T026 [P] [US3] Widget-тест аварийного режима в `app/test/widget/onboarding_gate_test.dart`: при `StorageRecoveryState.idle` онбординг не показывается (приоритет экрана восстановления, FR-002a); после принятия read-only онбординг показан, после подтверждения — не возвращается в той же сессии (FR-006a, FR-006b)

### Implementation for User Story 3

- [X] T027 [US3] Добавить в `complete()` (`app/lib/presentation/onboarding/cubit/onboarding_cubit.dart`) ограничение ожидания на `writeTimeout`: по истечении — `completed`, исход записи игнорируется, сбой логируется через `logger` без тоста (C7, FR-005b, research.md R4)
- [X] T028 [US3] Добавить туда же терминальность `completed`: повторный `complete()` в `submitting`/`completed` не вызывает репозиторий (C3), `resolve()` не откатывает `completed` в `required` (C4) — FR-006a, FR-007
- [X] T029 [US3] Вызвать `onboardingCubit.resolve()` в `app/lib/app/root_bloc_listener.dart` после `StorageDiSwitch` в ветках `StorageRecoveryRecovered` и `StorageRecoveryReadOnlyAccepted` — строго после регистрации репозитория (FR-006c, contracts §5)
- [X] T030 [US3] Проверить оба отказа `resolve()` порознь: локатор бросил (репозиторий не зарегистрирован) → `unknown` без исключения наружу (C5, FR-006b); репозиторий вернул `Result.failure` → `required` (C8, FR-001a). Не сливать эти случаи в одну ветку кода

**Checkpoint**: все три истории функциональны независимо

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T031 [P] A11y-тест в `app/test/widget/onboarding_accessibility_test.dart`: `meetsGuideline(androidTapTargetGuideline)`, `meetsGuideline(labeledTapTargetGuideline)`, отсутствие overflow при `textScaler` ×2 и при ширине экрана 320dp; screen reader видит заголовок и все три пункта, фокус при открытии — на заголовке (FR-010, FR-010a, FR-010b, SC-004)
- [X] T032 [P] Тест содержания в `app/test/widget/onboarding_gate_test.dart`: на экране присутствуют тексты всех трёх пунктов; для пункта (c) проверяются все три смысловых элемента FR-004d (внешний AI-сервис, передаётся текст о дне, настроение и дневник остаются на устройстве), а не просто непустая строка (FR-004, FR-004d, SC-005, конституция V)
- [X] T033 [P] Удалить `app/lib/presentation/onboarding/onboarding_placeholder_page.dart` и ключ `sectionOnboarding` из трёх `.arb`, если он больше нигде не используется (проверить `grep`)
- [X] T034 Прогнать `flutter analyze` и `flutter test` из `app/` — оба чисто; убедиться, что существующие widget-тесты шелла не сломались (T008)
- [X] T035 Проверить покрытие `OnboardingCubit` > 70% (`flutter test --coverage`, конституция VI)
- [ ] T036 Выполнить ручной прогон по [quickstart.md](./quickstart.md), шаги 1–10, на реальном Android-устройстве, включая аварийный режим хранилища
- [X] T037 Дописать в `project/process/lessons-learned.md` запись о реально возникших граблях этой фичи — только если что-то действительно потребовало переписывания (гипотетические уроки туда не пишутся)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: без зависимостей
- **Foundational (Phase 2)**: после Setup; **блокирует все истории**
- **US1 (Phase 3)**: после Phase 2
- **US2 (Phase 4)**: после US1 — доводит уже существующий экран, отдельного смысла без него не имеет
- **US3 (Phase 5)**: после Phase 2; независима от US2. T027/T028 дополняют `onboarding_cubit.dart`,
  созданный в T005 (T005 намеренно оставляет C3/C4/C7 неохваченными, чтобы US3 была отдельным
  проверяемым инкрементом, а не повтором уже сделанного)
- **Polish (Phase 6)**: после всех желаемых историй

### Внутри историй

- Тесты пишутся до реализации и должны падать
- T004 → T005 → T006 → T007 (состояние → Cubit → кодогенерация → DI)
- T013/T014/T016 связаны: роутер требует параметра, `main.dart` — конструктора, `AppRoot` — обоих
- T011 → T021 (компоновка правится в уже созданном файле)

### Parallel Opportunities

- T001 и T003 — параллельно; T002 после T001 (нужен шаблонный файл)
- T009 и T010 — параллельно (разные файлы)
- T012 параллельно с T013/T014 (разные файлы)
- T018, T019, T020 пишутся в один файл — параллелить нельзя, помечены [P] по признаку независимости от реализации; выполнять последовательно во избежание конфликтов
- T024, T025 — параллельно с T026 (разные файлы)
- T031, T032, T033 — параллельно

**Внимание**: T010/T018/T019/T020/T023a/T026/T032 адресуют один файл `onboarding_gate_test.dart` —
при работе в одиночку выполнять их подряд, а не «параллельно».

---

## Требования, намеренно оставленные без задач

- **FR-004e** (раскрытие показывается независимо от `aiEnabled`) и **FR-012** (оформление не
  добавляет шагов) — запреты: выполняются отсутствием условной логики, реализовывать нечего.
  Контролируются на ревью.
- **FR-011** (удаление данных = первый запуск) — следует из значения по умолчанию колонки
  `has_seen_onboarding` и удаления файла БД механизмом фичи 001. Отдельного кода не требует;
  проверяется вручную шагом 7 quickstart.

---

## Parallel Example: User Story 1

```bash
# Тесты US1 (разные файлы) — можно писать одновременно:
Task: "bloc_test на OnboardingCubit в app/test/presentation/onboarding_cubit_test.dart"
Task: "Widget-тест гейта в app/test/widget/onboarding_gate_test.dart"

# Реализация US1 — независимые файлы:
Task: "OnboardingPoints в app/lib/presentation/onboarding/widgets/onboarding_points.dart"
Task: "Параметр onboardingCubit в app/lib/app/app_root.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 — Setup (тексты)
2. Phase 2 — Foundational (Cubit + DI + тестовый хелпер) — **критично, блокирует всё**
3. Phase 3 — US1
4. **СТОП и проверка**: свежая установка показывает онбординг, одно касание ведёт на стол, повторный
   запуск онбординг не показывает
5. Это уже поставляемый инкремент

### Incremental Delivery

1. Setup + Foundational → фундамент готов
2. + US1 → MVP, проверяется независимо
3. + US2 → гарантии «один экран, одно касание», проверяется независимо
4. + US3 → устойчивость к сбоям и аварийному режиму
5. + Polish → a11y, раскрытие, чистка заглушки, ручной прогон

### Порядок с оглядкой на риск

`T008` (тестовый хелпер) выполнять **до** `T014` (редирект): как только гейт появится в роутере,
все существующие widget-тесты начнут проходить через него, и без `onboardingSeen: true` по умолчанию
упадут пять файлов сразу (research.md R7). Это самая вероятная поломка в фиче.

---

## Notes

- `[P]` — разные файлы, нет зависимостей
- Каждый widget-тест на `buildTestAppRoot()` обязан завершаться `await disposeTestAppRoot(tester);`
- `dart run build_runner build` — после любых правок `@freezed`/`@injectable`
- Коммит после каждой задачи или логической группы
- Задача с падающими тестами не считается выполненной (конституция, quality gate)
