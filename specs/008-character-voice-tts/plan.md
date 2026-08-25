# Implementation Plan: Озвучка реплик персонажей

**Branch**: `008-character-voice-tts` | **Date**: 2026-08-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/008-character-voice-tts/spec.md`

## Summary

Проговаривать реплику зверя вслух системным синтезом речи (`flutter_tts`, полностью офлайн)
сразу после появления бабла, с индивидуальными высотой и скоростью голоса на персонажа из
`assets/characters/characters.json`, последовательно (очередь) и с полным набором стоп-условий
(уход с экрана, сворачивание, новый цикл реакций, выключение тумблера, скринридер).

Ключевые архитектурные решения:

- **`core/speech/`** — новый сервис `SpeechSynthesizer` (абстракция + `flutter_tts`-реализация)
  по тому же образцу, что `NotificationScheduler`: интерфейс в `core/`, `Result<T>` наружу,
  мок в `test_app_root.dart`.
- **Голос персонажа — в конфиге, а не в коде**: новое value-object `CharacterVoice(pitch, rate)`
  внутри `Character` (одно поле-значение, а не два плоских — DRY-правило `CLAUDE.md`), парсится
  `CharacterCatalog`. Правка JSON меняет звучание без правок кода (FR-004).
- **Очередь и «кто сейчас говорит» — новый экранный Cubit `TableVoiceCubit`** в
  `presentation/table/`; `TableCubit`/`TableState` **не меняются вовсе** — озвучка подписана на
  уже существующее состояние стола, как и обещано в Assumptions спеки.
- **Аудио-поведение бесплатно от платформ**: Android — `speak(text, focus: true)` уже запрашивает
  `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` (ducking, FR-011a); iOS — категория `ambient` + `duckOthers`
  даёт и ducking, и уважение переключателя «без звука». Для Android беззвучный режим не выводится
  из аудиофокуса и читается собственным `MethodChannel` (тот же приём, что `IntegrityChannel.kt`).
- **Никаких новых сущностей в `domain/`/`data/` сверх голоса персонажа**: ни таблиц БД, ни
  миграций, ни новых настроек — переиспользуется существующий `soundEnabled`.

## Technical Context

**Language/Version**: Dart 3.13+ / Flutter (SDK-ограничение `^3.13.0` из `app/pubspec.yaml`)

**Primary Dependencies**: новая — `flutter_tts: ^4.2.5` (единственная добавляемая); существующие —
`flutter_bloc`, `freezed`, `get_it`/`injectable`, `flutter/services` (`MethodChannel`)

**Storage**: не затрагивается — ни новых таблиц, ни новых колонок; `soundEnabled` уже есть в
`user_settings` (002), схема БД и `schemaVersion` не меняются

**Testing**: `flutter_test` + `bloc_test` + `mocktail` — юнит-тесты `CharacterCatalog` (парсинг
голоса) и `CharacterVoice`, `bloc_test` на `TableVoiceCubit` (очередь, стоп-условия, гейты),
widget-тесты `table_page`/`settings_page` (состояние аватара, disabled-тумблер с пояснением);
платформенный канал `flutter_tts` в тестах подменяется моком в `test/support/test_app_root.dart`

**Target Platform**: Android (публикуется, ручная проверка обязательна) + iOS (собирается по той же
спецификации, ручная проверка до релиза в Google Play не требуется — Assumptions спеки)

**Performance Goals**: старт произнесения ≤ 1 с после появления бабла (SC-001); остановка при
выключении тумблера ≤ 0.5 с (SC-004); озвучка не влияет на FPS раскладки стола — синтез идёт в
платформенном потоке, Dart-сторона только шлёт команды

**Constraints**: полностью офлайн, без сети и квот (FR-015 + конституция §V — на Android
доступность определяется через `isLanguageInstalled`, который явно исключает голоса с
`isNetworkConnectionRequired`, поэтому текст дня не уходит в облачный синтез); отказ синтеза
никогда не виден пользователю (FR-012, SC-006); `TableCubit` не знает об озвучке

**Scale/Scope**: 1 новый пакет-зависимость, 4 новых файла в `core/speech/`, 1 value-object в
`domain/`, 2 новых файла Cubit/state в `presentation/table/`, 1 новый Kotlin-файл. Правки в 11
существующих файлах: `character.dart`, `character_catalog.dart`, `table_page.dart`,
`settings_cubit.dart`, `settings_state.dart`, `settings_page.dart`, `sound_section.dart`,
`injection_module.dart`, `AndroidManifest.xml`, `MainActivity.kt`, `characters.json`; плюс 3 строки
локализации × 3 языка и тестовая обвязка (`test_app_root.dart`, `mocks.dart`)

## Constitution Check

*GATE: пройден до Phase 0 и перепроверён после Phase 1 design.*

| Принцип | Как соблюдается | Статус |
|---|---|---|
| I. Слои, не фичи | `SpeechSynthesizer`/`SilentModeProbe` — сервисы в `core/` (как `NotificationScheduler`), `CharacterVoice` — чистый Dart в `domain/value_objects/`, очередь — в `presentation/table/`. `TableVoiceCubit` зависит только от `core`-абстракций и `SettingsRepository` (`domain/repositories/`), не от `data/` и не от другого экрана | PASS |
| II. Cubit и единый контракт состояний/ошибок | Новый `TableVoiceCubit` (Cubit, не Bloc-события) с Freezed sealed-состоянием; `SpeechSynthesizer` возвращает `Result<T>` через `SafeCallMixin`, исключения не летят в presentation. Отказ синтеза **намеренно не показывается пользователю** — см. Complexity Tracking | PASS (с обоснованным исключением) |
| III. Офлайн-first ядро | Синтез целиком на устройстве, без сети и без ai-proxy (FR-015); недоступность голоса не роняет экран и не блокирует запись дня | PASS |
| IV. Детерминированное время | Фича не использует время: очередь упорядочена приходом реплик, а не отметками времени; `DateTime.now()` не появляется | N/A |
| V. Секреты и приватность | Текст дня в синтез не передаётся — озвучивается только уже полученная реплика персонажа; на Android критерий доступности `isLanguageInstalled` исключает сетевые голоса, поэтому реплика не уходит в облако стороннего движка | PASS |
| VI. Тестируемость и чистота кода | `TableVoiceCubit` покрывается `bloc_test` (успех, каждое стоп-условие, гейты, `isClosed` после `await`) — цель >70%; моки `mocktail`; `SwitchListTile` не оборачивается в свой `Semantics` (`lessons-learned.md`), пояснение уходит в `subtitle:`; без `!`/небезопасных `as` | PASS |

**Post-design re-check (после Phase 1)**: `data-model.md`, контракты и `quickstart.md` не вводят ни
одной новой сущности сверх перечисленных, ни одного обращения `presentation/table/` к `data/`
(кроме уже существующего `CharacterCatalog` через `TableCubit`), ни одной новой настройки и ни
одной миграции БД. Оценка принципов не изменилась — гейт пройден повторно.

## Project Structure

### Documentation (this feature)

```text
specs/008-character-voice-tts/
├── plan.md              # этот файл
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   ├── speech-synthesizer.md      # контракт сервиса синтеза + пробы беззвучного режима
│   ├── character-voice-config.md  # расширение assets/characters/characters.json
│   └── table-voice-cubit.md       # контракт экранного Cubit-а очереди
├── checklists/requirements.md     # уже есть
└── tasks.md             # Phase 2 (/speckit-tasks — этим планом НЕ создаётся)
```

### Source Code (repository root)

```text
app/
├── lib/
│   ├── core/
│   │   └── speech/                          # НОВОЕ
│   │       ├── speech_synthesizer.dart          # интерфейс + SpeechRequest
│   │       ├── flutter_tts_speech_synthesizer.dart
│   │       ├── silent_mode_probe.dart           # интерфейс + всегда-false реализация
│   │       └── android_silent_mode_probe.dart   # MethodChannel к AudioModeChannel.kt
│   ├── domain/
│   │   ├── value_objects/character_voice.dart   # НОВОЕ (pitch + rate)
│   │   └── entities/character.dart              # + поле voice
│   ├── data/datasources/character_catalog.dart  # + парсинг "voice"
│   ├── presentation/
│   │   ├── table/
│   │   │   ├── cubit/table_voice_cubit.dart     # НОВОЕ — очередь + «кто говорит»
│   │   │   ├── cubit/table_voice_state.dart     # НОВОЕ
│   │   │   └── table_page.dart                  # проводка: enqueue/stop/визуальное состояние
│   │   └── settings/
│   │       ├── cubit/settings_cubit.dart        # + доступность озвучки
│   │       ├── cubit/settings_state.dart        # + VoiceAvailability
│   │       ├── settings_page.dart               # + прокидывание причины
│   │       └── widgets/sound_section.dart       # disabled + пояснение
│   ├── core/di/injection_module.dart            # регистрация сервисов и TableVoiceCubit
│   └── l10n/intl_{ru,en,uk}.arb                 # 3 новые строки
├── assets/characters/characters.json            # + "voice" у каждого зверя
├── android/app/src/main/kotlin/life/studyway/roundtablezoo/
│   ├── AudioModeChannel.kt                      # НОВОЕ — ringer/громкость
│   └── MainActivity.kt                          # регистрация канала
└── test/
    ├── support/{test_app_root,mocks}.dart       # моки SpeechSynthesizer/SilentModeProbe
    ├── data/character_catalog_test.dart         # + голос в парсинге
    ├── presentation/table_voice_cubit_test.dart # НОВОЕ
    └── widget/{table_page,table_accessibility,settings_page}_test.dart
```

**Structure Decision**: изменение ложится на существующую слоистую раскладку без новых
каталогов верхнего уровня: платформенный сервис — в `core/speech/` (рядом с `core/notifications/`,
`core/sharing/`), характеристика персонажа — в `domain/`, очередь и координация — в
`presentation/table/`. Экран «Настройки» трогается только в части доступности тумблера.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Отказ синтеза не превращается в видимую пользователю ошибку, вопреки принципу II («ошибка MUST быть поверхностна пользователю») | FR-012 и SC-006 требуют ровно обратного: на устройстве без голоса приложение обязано вести себя «как без озвучки вовсе» — без тостов, диалогов и крашей. Отказ фиксируется в `AppLogger` и отражается в состоянии тумблера (FR-013), то есть не «молчаливый сбой», а заявленный режим деградации | Тост на каждую несостоявшуюся озвучку прямо нарушил бы SC-006 и повторялся бы на каждую реплику на любом устройстве без нужного голоса |
| Собственный `MethodChannel` для беззвучного режима на Android | На Android режим звонка (silent/vibrate) не глушит поток `STREAM_MUSIC`, на котором говорит TTS, и аудиофокус этого не сообщает — FR-011b иначе невыполним. Приём уже применяется в проекте (`IntegrityChannel.kt`) | Сторонний пакет ради одного `getRingerMode()` добавил бы зависимость с собственным жизненным циклом; проверка громкости медиапотока в одиночку не отличает «пользователь убавил» от «беззвучный режим» |
