---
description: "Task list for 008-character-voice-tts"
---

# Tasks: Озвучка реплик персонажей

**Input**: Design documents from `/specs/008-character-voice-tts/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: тестовые задачи включены **не опционально** — конституция проекта (принцип VI)
требует `bloc_test` на каждый новый Cubit (>70%) и зелёный `flutter test` как gate завершения
задачи.

**Organization**: задачи сгруппированы по User Story из `spec.md`, в порядке приоритета
P1 → P2 → P3. Порядок фаз: US1 (P1) → US2 (P2) → US4 (P2) → US3 (P3).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: можно делать параллельно (разные файлы, нет зависимости от незавершённых задач)
- **[Story]**: к какой User Story относится задача
- Все пути — от корня репозитория; команды `flutter`/`dart run` запускаются из `app/`

## Path Conventions

Мобильное приложение со слоистой архитектурой: `app/lib/{core,domain,data,presentation}/`,
тесты — `app/test/{core,data,domain,presentation,widget,support}/`, платформенный код —
`app/android/app/src/main/kotlin/life/studyway/roundtablezoo/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: подключение зависимости и платформенные предусловия, без которых синтез молча не
заработает на устройстве

- [X] T001 Добавить `flutter_tts: ^4.2.5` в секцию dependencies `app/pubspec.yaml` и выполнить `flutter pub get`
- [X] T002 [P] Объявить `<queries><intent><action android:name="android.intent.action.TTS_SERVICE" /></intent></queries>` в `app/android/app/src/main/AndroidManifest.xml` — без этого на Android 11+ движок не виден приложению и доступность голоса всегда будет false
- [X] T003 [P] Убедиться, что эффективный `minSdk` ≥ 21 (сейчас `minSdk = flutter.minSdkVersion` в `app/android/app/build.gradle.kts` — проверить фактическое значение через `flutter build apk --debug` или свойства Flutter SDK); задать явное значение только если оно окажется ниже 21

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: сервисный слой озвучки в `core/speech/` и его подменяемость в тестах — от него
зависит каждая User Story

**⚠️ CRITICAL**: ни одна задача из Phase 3+ не начинается до завершения этой фазы

- [X] T004 [P] Создать интерфейс `SpeechSynthesizer` и `SpeechRequest` в `app/lib/core/speech/speech_synthesizer.dart` по `contracts/speech-synthesizer.md` §1 (методы `initialize`/`isAvailableFor`/`speak`/`stop`, все возвращают `Result<T>`)
- [X] T005 [P] Создать интерфейс `SilentModeProbe` и реализацию `NoSilentModeProbe` (всегда `false`) в `app/lib/core/speech/silent_mode_probe.dart` по `contracts/speech-synthesizer.md` §2
- [X] T006 Реализовать `FlutterTtsSpeechSynthesizer` в `app/lib/core/speech/flutter_tts_speech_synthesizer.dart`: `awaitSpeakCompletion(true)` и iOS-категория `ambient`+`mixWithOthers`+`duckOthers` в `initialize`, `setLanguage`/`setPitch`/`setSpeechRate` перед каждым `speak`, `speak(text, focus: true)` на Android, весь платформенный вызов — через `SafeCallMixin` (S1–S7 контракта; зависит от T004)
- [X] T006a `initialize()` вызывается идемпотентно **изнутри** `isAvailableFor`/`speak` при первом обращении (guard по флагу, повторные вызовы — no-op); снаружи его не зовёт никто, в `main.dart` он не добавляется (`contracts/speech-synthesizer.md` §1, «Регистрация»; зависит от T006)
- [X] T006b В `isAvailableFor` использовать **`isLanguageInstalled` на Android** (метод отбрасывает голоса с `isNetworkConnectionRequired`, то есть гарантирует синтез на устройстве) и `isLanguageAvailable` на остальных платформах; ветка выбирается по `defaultTargetPlatform`. Это единственное место, обеспечивающее FR-015 и принцип V конституции — реплика не должна уходить в облачный голос движка (research.md R3; зависит от T006)
- [X] T007 Реализовать `AndroidSilentModeProbe` на `MethodChannel('life.studyway.roundtablezoo/audio')` в `app/lib/core/speech/android_silent_mode_probe.dart`, ошибка канала → `false` (зависит от T005)
- [X] T008 Создать `app/android/app/src/main/kotlin/life/studyway/roundtablezoo/AudioModeChannel.kt` с методом `isSilent` (`ringerMode != RINGER_MODE_NORMAL || getStreamVolume(STREAM_MUSIC) == 0`) и зарегистрировать его в `MainActivity.configureFlutterEngine` рядом с `IntegrityChannel`
- [X] T009 Зарегистрировать `SpeechSynthesizer` (`@LazySingleton`) и `SilentModeProbe` (выбор по `defaultTargetPlatform`, как у `IntegrityTokenProvider`) в `app/lib/core/di/injection_module.dart`, выполнить `dart run build_runner build --delete-conflicting-outputs` (зависит от T006, T007)
- [X] T010 Добавить `MockSpeechSynthesizer`/`MockSilentModeProbe` в `app/test/support/mocks.dart` и перерегистрировать их с безопасными заглушками в `buildTestAppRoot()` (`app/test/support/test_app_root.dart`) — профилактика `MissingPluginException` из `project/process/lessons-learned.md` (зависит от T009)
- [X] T011 [P] Написать юнит-тест `app/test/core/speech_synthesizer_test.dart`: `speak` применяет язык/высоту/скорость перед произнесением, исключение платформы превращается в `Result.failure`, недоступный движок даёт `isAvailableFor → success(false)`, повторные вызовы не переинициализируют движок (зависит от T006, T006a)
- [X] T011a [P] Тест там же на офлайн-критерий: при `defaultTargetPlatform == android` доступность спрашивается через `isLanguageInstalled`, а не `isLanguageAvailable` — регрессия на FR-015 и принцип V (зависит от T006b)

**Checkpoint**: сервис синтеза существует, зарегистрирован в DI и не ломает ни один существующий widget-тест — можно начинать User Stories

---

## Phase 3: User Story 1 — Услышать реплику зверя вслух (Priority: P1) 🎯 MVP

**Goal**: полученная реплика проговаривается вслух на языке интерфейса, а любое из стоп-условий
(уход с экрана, сворачивание, недоступность, беззвучный режим, скринридер) надёжно её глушит

**Independent Test**: отметить настроение, ввести текст дня, тапнуть по одному зверю — услышать
реплику; уйти с экрана во время произнесения — голос замолкает

### Tests for User Story 1

- [X] T012 [P] [US1] `bloc_test` в `app/test/presentation/table_voice_cubit_test.dart`: одна реплика при открытых гейтах выставляет и сбрасывает `speakingCharacterId`; `stopAll()` во время произнесения зовёт `synthesizer.stop()`; `close()` не даёт `emit` после закрытия (пункты 1, 4, 10 из `contracts/table-voice-cubit.md` §5)
- [X] T013 [P] [US1] `bloc_test` в `app/test/presentation/table_voice_cubit_test.dart`: недоступность озвучки и активный скринридер запрещают постановку в очередь; беззвучный режим пропускает произнесение; `Result.failure` от синтезатора не эмитит ошибку наружу (пункты 6, 7, 8, 9)
- [X] T014 [P] [US1] Widget-тест в `app/test/widget/table_page_test.dart`: впервые показанная реплика уходит в `enqueue`, восстановленная (`restored: true`) — нет; уход со страницы вызывает остановку
- [X] T015 [P] [US1] Widget-тест в `app/test/widget/table_accessibility_test.dart`: при `accessibilityFeaturesTestValue` с `accessibleNavigation: true` озвучка не запускается (FR-014)

### Implementation for User Story 1

- [X] T016 [US1] Создать `TableVoiceState` (Freezed: `speakingCharacterId`, `queueLength`) в `app/lib/presentation/table/cubit/table_voice_state.dart` по `data-model.md` §5 и прогнать `build_runner`
- [X] T017 [US1] Реализовать `TableVoiceCubit` в `app/lib/presentation/table/cubit/table_voice_cubit.dart`: `enqueue`/`stopAll`/`onScreenReaderChanged`/`onVoiceAvailabilityChanged`, произнесение одной реплики за раз, проверка `SilentModeProbe.isSilent()` непосредственно перед `speak` (V4), `isClosed` после каждого `await` (V7), молчаливое проглатывание `failure` (V6) (зависит от T016)
- [X] T018 [US1] Зарегистрировать `TableVoiceCubit` как `@injectable` factory в `app/lib/core/di/injection_module.dart` и прогнать `build_runner` (зависит от T017)
- [X] T019 [US1] Провести Cubit в `app/lib/presentation/table/table_page.dart`: создание в `initState`, `BlocProvider.value`, закрытие в `dispose` (FR-009), `stopAll()` в `didChangeAppLifecycleState` для `paused` и `inactive` рядом с существующим `flushDayText` (FR-011, без возобновления при возврате) (зависит от T018)
- [X] T020 [US1] В `_RoundTableState.didUpdateWidget` (`app/lib/presentation/table/table_page.dart`) ставить реплику в очередь там же, где выставляется `_revealing[id] = true` для нового `CharacterSlotSpoken(restored: false)` — старт параллельно анимации раскрытия, не по `onRevealed` (FR-001, research.md R9)
- [X] T021 [US1] Вынести вычисление доступности озвучки в одну функцию рядом с сервисом (`app/lib/core/speech/speech_synthesizer.dart` или соседний файл в `core/speech/`): «доступна = движок ответил И есть голос для языка интерфейса»; она станет единственным источником и для «Стола», и для Настроек (снимает риск расхождения с T033)
- [X] T021a [US1] В `_TablePageState.build` (`app/lib/presentation/table/table_page.dart`) читать `MediaQuery.accessibleNavigationOf(context)` → `onScreenReaderChanged` и вызывать функцию из T021 для `Localizations.localeOf(context).toLanguageTag()` → `onVoiceAvailabilityChanged`, пересчитывая при смене языка (FR-002, FR-012, FR-014; зависит от T021)
- [X] T022 [US1] В `_RoundTableState._seatFor` (`app/lib/presentation/table/table_page.dart`) вычислять `CharacterVisualState.speaking` как `isRevealing || speakingCharacterId == character.id` (FR-016), не трогая `SpeakingBubble` и `CharacterAvatar`

**Checkpoint**: реплика звучит и корректно замолкает; на устройстве без голоса приложение работает молча и без ошибок — US1 поставляема как MVP

---

## Phase 4: User Story 2 — Узнавать зверя по голосу (Priority: P2)

**Goal**: у каждого зверя собственный тембр, задаваемый конфигом персонажей, а не кодом

**Independent Test**: получить реплики кота и бегемота подряд, не глядя на экран, и различить их
на слух; изменить `voice.pitch` в JSON, сделать hot restart — звучание изменилось

### Tests for User Story 2

- [X] T023 [P] [US2] Юнит-тесты в `app/test/data/character_catalog_test.dart`: `voice` парсится; отсутствующий, не-объектный или частичный `voice` даёт `CharacterVoice.neutral`; значения вне диапазона зажимаются; сломанный `voice` не роняет загрузку каталога (`contracts/character-voice-config.md` §1)
- [X] T024 [P] [US2] Юнит-тест в `app/test/data/character_catalog_test.dart` на реальном ассете `app/assets/characters/characters.json`: `pitch(cat) > pitch(dog) > pitch(crocodile) > pitch(hippo)` и тот же порядок по `rate` (FR-003, `contracts/character-voice-config.md` §2)

### Implementation for User Story 2

- [X] T025 [P] [US2] Создать value-object `CharacterVoice` (`pitch`, `rate`, константа `neutral`) в `app/lib/domain/value_objects/character_voice.dart` и прогнать `build_runner` (`data-model.md` §1)
- [X] T026 [US2] Добавить обязательное поле `voice` в `app/lib/domain/entities/character.dart` и перегенерировать Freezed (зависит от T025)
- [X] T027 [US2] Парсить `voice` с зажатием диапазонов и дефолтом `neutral` в `_parseCharacter` (`app/lib/data/datasources/character_catalog.dart`) — не бросая `FormatException` на этом поле (зависит от T026)
- [X] T028 [P] [US2] Проставить стартовые `voice` четырём зверям в `app/assets/characters/characters.json` по таблице `contracts/character-voice-config.md` §2
- [X] T029 [US2] Передавать `character.voice` в `enqueue` из `_RoundTableState` (`app/lib/presentation/table/table_page.dart`) и далее в `SpeechRequest` без промежуточных констант (FR-004) (зависит от T027, T020)

**Checkpoint**: звери звучат по-разному, звучание правится только JSON-ом — US1 + US2 работают вместе

---

## Phase 5: User Story 4 — Управлять озвучкой из Настроек (Priority: P2)

**Goal**: пользователь выключает озвучку тумблером, а на устройстве без голоса или со включённым
скринридером тумблер честно неактивен с пояснением

**Independent Test**: выключить тумблер, получить реплику — тишина при видимом бабле; перезапустить
приложение — тумблер по-прежнему выключен

### Tests for User Story 4

- [X] T030 [P] [US4] Widget-тест в `app/test/widget/settings_page_test.dart`: при недоступной озвучке и при активном скринридере `SwitchListTile` отключён и показывает соответствующее пояснение; сохранённое значение настройки при этом не записывается (FR-013, FR-013a)
- [X] T030a [P] [US4] Проверить, что FR-007 (тумблер переживает перезапуск) уже обеспечен `soundEnabled` из `specs/002-settings-and-reminders` — если регрессионного теста на сохранение этого поля в `app/test/data/settings_repository_test.dart` нет, добавить его; новой логики хранения не заводить
- [X] T031 [P] [US4] `bloc_test` в `app/test/presentation/table_voice_cubit_test.dart`: `soundEnabled: false` из `watch()` запрещает постановку; переход `true → false` во время произнесения останавливает голос **и очищает очередь**, а обратное включение ничего не доигрывает (FR-006, FR-008)

### Implementation for User Story 4

- [X] T032 [P] [US4] Добавить строки пояснений (нет движка/голоса для языка; читает скринридер) в `app/lib/l10n/intl_ru.arb`, `intl_en.arb`, `intl_uk.arb` и перегенерировать локализацию
- [X] T033 [US4] Добавить `VoiceAvailability` (`available`/`noVoiceForLanguage`/`screenReaderActive`) в `app/lib/presentation/settings/cubit/settings_state.dart`; доступность вычислять **той же функцией из T021**, не дублируя условие в `SettingsCubit`, и не изменяя хранимое значение `soundEnabled` (`data-model.md` §6; зависит от T021, T032)
- [X] T034 [US4] В `app/lib/presentation/settings/settings_page.dart` читать `MediaQuery.accessibleNavigationOf(context)`, отдавать приоритет причине `screenReaderActive` и прокидывать её в `SoundSection` (зависит от T033)
- [X] T035 [US4] В `app/lib/presentation/settings/widgets/sound_section.dart` делать `onChanged: null` при недоступности и показывать причину в `subtitle:` — без обёртки `Semantics` поверх `SwitchListTile` (`lessons-learned.md`) (зависит от T034)
- [X] T036 [US4] Подписать `TableVoiceCubit` (`app/lib/presentation/table/cubit/table_voice_cubit.dart`) на `SettingsRepository.watch()`: гейт по `soundEnabled` при постановке и `stopAll()` в момент выключения тумблера (FR-006, FR-008) (зависит от T017)

**Checkpoint**: озвучкой можно управлять, а недоступность объяснена — US1, US2, US4 работают вместе

---

## Phase 6: User Story 3 — Слушать нескольких зверей по очереди (Priority: P3)

**Goal**: реплики нескольких зверей звучат строго последовательно, в порядке появления баблов, а
новый цикл реакций чистит остаток очереди

**Independent Test**: тапнуть по двум-трём зверям подряд, не дожидаясь ответов — реплики звучат
одна за другой, без наложения

### Tests for User Story 3

- [X] T037 [P] [US3] `bloc_test` в `app/test/presentation/table_voice_cubit_test.dart`: две реплики произносятся строго последовательно и в порядке постановки; `enqueue` во время произнесения не прерывает текущую; после `stopAll()` ни одна из оставшихся не звучит (V1, V2, V3, V5)
- [X] T038 [P] [US3] Widget-тест в `app/test/widget/table_page_test.dart`: тап по персонажу во время произнесения останавливает озвучку предыдущего цикла (FR-010)

### Implementation for User Story 3

- [X] T039 [US3] Достроить обработку очереди в `app/lib/presentation/table/cubit/table_voice_cubit.dart`: последовательный проход `List<VoiceUtterance>` с обновлением `queueLength`, следующий элемент — только после завершения предыдущего `speak` (FR-005; зависит от T017)
- [X] T040 [US3] Вызывать `stopAll()` в обработчике тапа по персонажу в `_RoundTableState._seatFor` (`app/lib/presentation/table/table_page.dart`) перед `onCharacterTap` — новый цикл реакций (FR-010, research.md R12)
- [X] T041 [US3] Убедиться, что ожидающая очереди реплика не показывает аватар в состоянии «говорит» (FR-016a), и покрыть это widget-тестом в `app/test/widget/table_page_test.dart` (зависит от T022, T039)

**Checkpoint**: все четыре User Story работают независимо и вместе

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T042 [P] Регрессионный widget-тест `app/test/widget/diary_page_test.dart`: экран «Дневник» не озвучивает ни одной реплики ни при открытии, ни при прокрутке (FR-017)
- [X] T043 Прогнать gate: `flutter analyze` без ошибок и `flutter test` полностью зелёный (конституция, §Рабочий процесс п. 5)
- [ ] T044 Выполнить ручной прогон всех 16 сценариев из [quickstart.md](./quickstart.md) на реальном Android-устройстве (сценарии 6, 7, 14 на эмуляторе недостоверны). Пороги SC-001 (≤1 с до старта) и SC-004 (≤0.5 с до остановки) **замерить**, а не оценить на глаз — секундомер или лог с отметками времени вокруг вызовов `speak`/`stop`
- [X] T045 [P] Добавить строку про `specs/008-character-voice-tts` в таблицу «Реализованные фичи» в `CLAUDE.md`
- [X] T046 [P] Дописать в `project/process/lessons-learned.md` реальные грабли, если что-то потребовало переписывания (гипотетические уроки не писать)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: без зависимостей, стартует сразу
- **Foundational (Phase 2)**: зависит от Phase 1 — БЛОКИРУЕТ все User Stories
- **US1 (Phase 3)**: зависит только от Phase 2
- **US2 (Phase 4)**: зависит от Phase 2; T029 дополнительно от T020 (US1)
- **US4 (Phase 5)**: зависит от Phase 2; T033 дополнительно от T021 (US1), T036 — от T017 (US1)
- **US3 (Phase 6)**: зависит от Phase 2; T039/T041 дополнительно от T017/T022 (US1)
- **Polish (Phase 7)**: после всех поставляемых историй

### User Story Dependencies

- **US1 (P1)**: независима — единственная, дающая ценность сама по себе
- **US2 (P2)**: технически независима (голос применяется к любой реплике), но проверяется на слух только вместе с US1
- **US4 (P2)**: независима от US2 и US3; трогает `SettingsCubit` и один метод `TableVoiceCubit`
- **US3 (P3)**: расширяет обработку очереди внутри `TableVoiceCubit`, не переписывая US1

### Within Each User Story

- Тесты пишутся первыми и должны падать до реализации
- Value-object → entity → парсер → потребитель (US2)
- Состояние → Cubit → DI → проводка в виджете (US1)
- `build_runner` — сразу после каждой правки `@freezed`/`@injectable`, до следующей задачи

### Parallel Opportunities

- T002, T003 — параллельно друг другу
- T004, T005 — параллельно; T006a и T006b — последовательно после T006 (один файл); T011 и T011a — параллельно друг другу после T006/T006b
- T012–T015 (тесты US1) — все параллельно; T021 (общая функция доступности) блокирует и T021a, и T033
- T023, T024, T025, T028 — параллельно
- T030, T030a, T031 — параллельно; T032 — параллельно им
- T037, T038 — параллельно
- T042, T045, T046 — параллельно
- После Phase 2 разные истории могут вестись параллельно разными людьми; конфликтная точка одна — `table_page.dart` (T020, T022, T029, T040, T041) и `table_voice_cubit.dart` (T017, T036, T039)

---

## Parallel Example: User Story 1

```bash
# Тесты US1 — все четыре пишутся параллельно:
Task: "bloc_test одиночной реплики и stopAll в app/test/presentation/table_voice_cubit_test.dart"
Task: "bloc_test гейтов и молчаливой деградации в app/test/presentation/table_voice_cubit_test.dart"
Task: "widget-тест enqueue/restored в app/test/widget/table_page_test.dart"
Task: "widget-тест скринридера в app/test/widget/table_accessibility_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup (T001–T003)
2. Phase 2: Foundational (T004–T011a) — критично, блокирует всё
3. Phase 3: User Story 1 (T012–T022)
4. **STOP and VALIDATE**: сценарии 1, 4, 12 из `quickstart.md` на устройстве — реплика звучит,
   замолкает при уходе, молчит без голоса

На этом фича уже поставляема: единственный зверь говорит вслух нейтральным голосом.

### Incremental Delivery

- **+ US2** (T023–T029) — звери начинают звучать по-разному; проверка сценариями 10, 11
- **+ US4** (T030–T036, включая T030a) — появляется управление и честный disabled-тумблер; сценарии 5, 8, 9, 15
- **+ US3** (T037–T041) — корректная очередь при нескольких зверях; сценарии 2, 3
- **+ Polish** (T042–T046) — gate, ручной прогон, документация

### Порядок при работе в одиночку

Строго по фазам сверху вниз: каждая следующая история опирается на уже зелёные тесты предыдущей,
а конфликтующие правки `table_page.dart` не пересекаются во времени.
