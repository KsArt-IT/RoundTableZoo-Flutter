# Phase 0 — Research: Озвучка реплик персонажей

Все открытые технические вопросы, вытекающие из `spec.md` и Technical Context `plan.md`.
Источник фактов о плагине — исходники `flutter_tts 4.2.5` (`lib/flutter_tts.dart`,
`android/.../FlutterTtsPlugin.kt`, `ios/Classes/SwiftFlutterTtsPlugin.swift`), не README.

---

## R1. Чем синтезировать речь

**Decision**: `flutter_tts: ^4.2.5` — единственная новая зависимость.

**Rationale**: обёртка ровно над системными механизмами, которые требует спека (Android
`TextToSpeech`, iOS `AVSpeechSynthesizer`); поддерживает всё, что нужно фиче, без доработок:
`setLanguage`, `isLanguageAvailable`/`isLanguageInstalled`, `setPitch`, `setSpeechRate`, `speak`,
`stop`, `awaitSpeakCompletion`. Ни ключей, ни сети, ни аккаунтов — совместимо с FR-015 и
принципом V конституции. Активно поддерживается, SDK-ограничение `>=3.4.0 <4.0.0` совместимо с
`^3.13.0` проекта.

**Alternatives considered**: собственный `MethodChannel` поверх `TextToSpeech`/`AVSpeechSynthesizer`
— пришлось бы писать и поддерживать две платформенные реализации ради API, которое уже есть;
`audioplayers` + заранее записанные файлы — реплики генерируются AI на лету, озвучить их
файлами невозможно; облачный TTS — прямо запрещён FR-015 и принципом V.

---

## R2. Как задавать тембр персонажа и в каких единицах

**Decision**: в `assets/characters/characters.json` у каждого зверя появляется объект
`"voice": {"pitch": <double>, "rate": <double>}`. `pitch` — 0.5…2.0 (1.0 = обычный), `rate` —
0.0…1.0 (0.5 ≈ обычный темп). Значения на старте:

| Персонаж | pitch | rate |
|---|---|---|
| cat | 1.50 | 0.62 |
| dog | 1.15 | 0.56 |
| crocodile | 0.85 | 0.46 |
| hippo | 0.70 | 0.40 |

**Rationale**: диапазоны — общие для обеих платформ в API плагина; Android-сторона сама
пересчитывает `rate` (`setSpeechRate(rate * 2.0f)`), поэтому 0.5 соответствует системной норме и
на Android, и на iOS. Значения дают ровно тот относительный порядок, который требует FR-003
(кот — самый высокий и быстрый, бегемот — самый низкий и медленный), с шагом, различимым на слух.
Хранение рядом с `emoji`/`colorHex` — прямое требование FR-003 и делает FR-004 (изменение без
правок кода) верным по построению.

**Alternatives considered**: разные системные голоса через `setVoice`/`getVoices` — состав голосов
непредсказуем на конкретном устройстве, узнаваемость персонажа стала бы устройство-зависимой;
константы в Dart-коде — прямо нарушает FR-004.

---

## R3. Как определять доступность озвучки (FR-012)

**Decision**: доступность = «движок ответил» И «для языка интерфейса есть локальный голос».
Проверка — по языковому тегу текущей локали интерфейса (`Localizations.localeOf(context)`):

- Android — `isLanguageInstalled(tag)`;
- iOS/прочие — `isLanguageAvailable(tag)`;
- `MissingPluginException`/`PlatformException`/любое исключение → недоступно (движка нет).

**Rationale**: `isLanguageInstalled` в Android-реализации плагина явно отбрасывает голоса с
`isNetworkConnectionRequired`, то есть выбирает ровно офлайн-голоса — это одновременно закрывает
FR-015 и принцип V конституции (реплика не уходит в облачный синтез Google). iOS-плагин метода
`isLanguageInstalled` не реализует, но `AVSpeechSynthesizer` синтезирует на устройстве, поэтому
там достаточно `isLanguageAvailable`. Язык берётся из локали интерфейса, а не из локали ОС —
FR-002.

**Alternatives considered**: `getLanguages`/`getVoices` со сравнением списков — те же данные более
громоздким путём и с ручным разбором тегов; проверка один раз при старте приложения — не
переживает смену языка в Настройках, чего требует FR-012.

---

## R4. Последовательная очередь без наложения (FR-005)

**Decision**: `awaitSpeakCompletion(true)` один раз при инициализации; очередь — обычный
`List<VoiceUtterance>` внутри `TableVoiceCubit`, обрабатываемый по одному: `await speak(...)` →
следующий. Очередной мод плагина (`setQueueMode`) не используется.

**Rationale**: с `awaitSpeakCompletion(true)` future `speak` завершается по окончании
произнесения, поэтому «одна за другой в порядке появления баблов» получается тривиальным циклом,
без гонок. Собственная очередь — единственный способ выполнить FR-010/FR-009 (очистить
непроизнесённое, не трогая уже звучащее иначе как явным `stop`), и она же нужна для FR-016
(«кто сейчас говорит») — плагин такого состояния не отдаёт. Важное ограничение Android-реализации:
`awaitSpeakCompletion` работает только при `queueMode == QUEUE_FLUSH` (значение по умолчанию) —
ещё одна причина не трогать `setQueueMode`.

**Alternatives considered**: `setQueueMode(QUEUE_ADD)` и передача всех реплик в плагин — потеря
контроля над очередью (нельзя выкинуть непроизнесённые, не оборвав текущую) и отсутствие сигнала
«кто говорит сейчас».

---

## R5. Куда положить очередь: Cubit, а не сервис-синглтон

**Decision**: новый экранный `TableVoiceCubit` (`@injectable` factory, свежий на каждый заход на
`/table`), состояние — Freezed. `TableCubit` и `TableState` не меняются; `TablePage` в
`BlocListener` на `TableState` передаёт в него появившиеся реплики.

**Rationale**: соответствует Assumptions спеки («за переключение реплики на речь отвечает
presentation-слой») и принципу II. Экранный scope сам по себе закрывает FR-009: `dispose` страницы
закрывает Cubit, `close()` останавливает синтез — уход с экрана не может «забыть» остановиться.
`@lazySingleton` был бы прямым повторением грабель из `lessons-learned.md` («глобальный Cubit,
который реально читается в дереве»).

**Alternatives considered**: сервис-синглтон в `core/` с внутренней очередью — состояние «кто
говорит» пришлось бы вытаскивать в UI отдельным стримом, то есть строить Cubit вручную; логика в
`TableCubit` — противоречит спеке и раздувает и без того самый большой Cubit проекта.

---

## R6. Ducking чужого аудио (FR-011a)

**Decision**: Android — `speak(text, focus: true)`; iOS — один раз при инициализации
`setIosAudioCategory(IosTextToSpeechAudioCategory.ambient, [IosTextToSpeechAudioCategoryOptions.mixWithOthers, IosTextToSpeechAudioCategoryOptions.duckOthers])`.

**Rationale**: Android-реализация плагина при `focus: true` запрашивает
`AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` и отпускает фокус по завершении/`stop` — это ровно
«приглушить на время реплики и вернуть громкость», без собственного кода. На iOS категория
`ambient` с `duckOthers` даёт то же поведение и вдобавок закрывает R7.

**Alternatives considered**: `AUDIOFOCUS_GAIN` (полная пауза чужого плеера) — FR-011a явно требует
не останавливать чужое воспроизведение; ничего не запрашивать — реплика наложилась бы на музыку в
полную громкость.

---

## R7. Беззвучный режим устройства (FR-011b)

**Decision**: iOS — покрыт категорией `ambient` из R6 (система сама молчит при включённом
переключателе «без звука»). Android — новый `SilentModeProbe`, спрашиваемый перед каждой репликой;
реализация — `MethodChannel('life.studyway.roundtablezoo/audio')` к новому `AudioModeChannel.kt`:
беззвучно, если `ringerMode != RINGER_MODE_NORMAL` **или** `getStreamVolume(STREAM_MUSIC) == 0`.
На всех платформах, кроме Android, — реализация, всегда возвращающая «не беззвучно».

**Rationale**: на Android TTS играет в `STREAM_MUSIC`, который режим звонка не глушит, и
аудиофокус об этом не сообщает — без платформенного вопроса FR-011b невыполним. Проверка обоих
условий отличает «пользователь молчит намеренно» от «просто убавлено»: одного `ringerMode` мало
для устройств, где медиа выкручено в ноль. Приём (собственный `MethodChannel` в `MainActivity`)
уже применён в проекте для Play Integrity, так что не вводит нового класса решений.

**Alternatives considered**: сторонний пакет для режима звонка — новая зависимость ради одного
геттера; игнорировать беззвучный режим на Android — прямое нарушение FR-011b и главного сценария
US4 («в общественном месте»).

---

## R8. Скринридер (FR-014)

**Decision**: гейт по `MediaQuery.accessibleNavigationOf(context)` (тот же флаг, что
`SemanticsBinding.instance.accessibilityFeatures.accessibleNavigation`). Значение читается в
`TablePage` и в `SettingsPage` и передаётся вниз: в `TableVoiceCubit` — как запрет ставить в
очередь и команда `stop()` при включении на лету, в `SoundSection` — как причина `disabled`.

**Rationale**: флаг переживает включение/выключение TalkBack на лету (`MediaQuery` перестраивает
зависящие виджеты), не требует платформенного кода и напрямую подменяется в widget-тестах через
`tester.platformDispatcher.accessibilityFeaturesTestValue`. Читать его в UI-слое, а не в Cubit —
единственный способ не тащить Flutter-биндинги в Cubit.

**Alternatives considered**: `SemanticsBinding...` напрямую в Cubit — Cubit стал бы зависеть от
глобального биндинга и потерял бы проверяемость; определять «скринридер сейчас читает» точечно
(по каждому объявлению) — платформенного API для этого нет.

---

## R9. Момент старта и связь с анимацией раскрытия

**Decision**: реплика ставится в очередь в тот же момент, когда `TableState` впервые отдаёт для
персонажа `CharacterSlotSpoken(restored: false)` — то есть одновременно с созданием
`SpeakingBubble`, не дожидаясь `onRevealed`. Слот с `restored: true` в очередь не попадает
никогда.

**Rationale**: Clarifications-решение («речь и раскрытие текста идут независимо») и SC-001.
Условие `restored: false` — ровно то, которое `_RoundTable.didUpdateWidget` уже использует для
запуска эффекта раскрытия, поэтому «озвучиваем то, что впервые показали» не требует нового
признака в состоянии и автоматически исключает восстановленные из БД реплики (Assumptions спеки).

**Alternatives considered**: старт по `onRevealed` — задержка в несколько секунд, противоречит
SC-001; синхронизация скорости раскрытия со скоростью речи — длительность произнесения заранее
неизвестна, а перезапись длительности анимации ломает существующие тесты `SpeakingBubble`.

---

## R10. Визуальное состояние персонажа при озвучке (FR-016/FR-016a)

**Decision**: `CharacterVisualState.speaking` = `isRevealing || voiceState.speakingCharacterId ==
character.id`; в остальном логика `_RoundTableState._seatFor` не меняется.

**Rationale**: минимальная правка одного выражения, дающая ровно FR-016 (в «ответил» только когда
и текст раскрыт, и голос замолчал) и FR-016a (ожидание очереди — не «говорит», потому что
`speakingCharacterId` в этот момент указывает на другого персонажа). Ни новых полей в `TableState`,
ни изменения контракта `SpeakingBubble.onRevealed`.

**Alternatives considered**: держать признак в `TableState` — вернуло бы озвучку в `TableCubit`
вопреки спеке; отдельный `AnimationController` для «говорения» — новая анимация не заказана,
YAGNI.

---

## R11. Все стоп-условия одной ручкой

**Decision**: единственный внутренний метод `TableVoiceCubit.stopAll()` (очистить очередь +
`synthesizer.stop()` + сбросить `speakingCharacterId`) вызывается из пяти мест: `close()` (уход с
экрана — FR-009), `AppLifecycleState.paused`/`inactive` (FR-011), начало нового цикла реакций
(FR-010), выключение `soundEnabled` (FR-008), включение скринридера на лету (FR-014).

**Rationale**: единая точка вместо пяти похожих ветвлений (DRY, KISS), и она же — единственное
место, где тестируется SC-004/SC-005. `AppLifecycleState.inactive` включён потому, что входящий
звонок на Android/iOS часто даёт именно его, а не `paused`; `TablePage` уже реализует
`WidgetsBindingObserver` для `flushDayText`, новых наблюдателей не появляется.

**Alternatives considered**: полагаться на потерю аудиофокуса при звонке — плагин не отдаёт
события фокуса в Dart; останавливать только текущую реплику, не чистя очередь — FR-010 явно
требует очистки.

---

## R12. Реакция на новый цикл реакций (FR-010)

**Decision**: «новый цикл» = тап по персонажу в `_RoundTableState` (там же, где уже
выставляется `_activeCharacterId`) — оттуда вызывается `stopAll()` перед `onCharacterTap`.

**Rationale**: тап — единственное место, где пользователь инициирует новые реплики, и оно уже
перехватывается в UI; определять цикл по смене состояния (`loading`-слоты) сложнее и ложно
срабатывает при восстановлении. Совпадает с определением «нового цикла» в Assumptions спеки.

**Alternatives considered**: считать циклом любой переход слота в `loading` — то же самое, но с
лишним выводом состояния и риском повторных срабатываний при повторных `emit`.

---

## R13. Тесты и платформенный канал

**Decision**: `SpeechSynthesizer` и `SilentModeProbe` перерегистрируются моками `mocktail` в
`test/support/test_app_root.dart` при каждом `buildTestAppRoot()`, как уже сделано для
`NotificationScheduler`; `TableVoiceCubit` в собственных тестах конструируется напрямую с моками.

**Rationale**: прямая профилактика зафиксированных в `lessons-learned.md` грабель «виджет-тесты и
реальный платформенный канал» — без этого любой widget-тест, доходящий до `/table` или
`/settings`, упадёт с `MissingPluginException`. Правило из того же урока: сервис, который
резолвится через `getIt` и трогает platform channel, обязан быть подменяемым в `test_app_root`.

**Alternatives considered**: `TestDefaultBinaryMessengerBinding` с ручным ответчиком на канал
`flutter_tts` — привязывает тесты к именам методов плагина вместо собственного интерфейса.
