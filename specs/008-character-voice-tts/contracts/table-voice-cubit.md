# Contract: `TableVoiceCubit`

Экранный Cubit озвучки (`presentation/table/cubit/table_voice_cubit.dart`). Свежий экземпляр на
каждый заход на `/table` (`@injectable` factory), как `TableCubit` и `SettingsCubit`.

Состояние — `TableVoiceState` (`data-model.md` §5).

---

## 1. Зависимости

```dart
TableVoiceCubit({
  required SpeechSynthesizer synthesizer,   // core/speech
  required SilentModeProbe silentModeProbe, // core/speech
  required SettingsRepository settingsRepository, // domain/repositories
})
```

`SettingsRepository.watch()` — источник `soundEnabled` (тот же приём, что в `TableCubit`).
Ни одного другого Cubit-а среди зависимостей (принцип I).

---

## 2. Публичное API

| Метод | Кто зовёт | Что делает |
|---|---|---|
| `enqueue({required String characterId, required String text, required CharacterVoice voice, required String languageTag})` | `TablePage` — на каждую впервые показанную реплику (`CharacterSlotSpoken(restored: false)`) | Ставит в очередь и запускает обработку, если все гейты открыты (`data-model.md` §5); иначе — no-op |
| `onScreenReaderChanged({required bool active})` | `TablePage` — из `MediaQuery.accessibleNavigationOf` | Запоминает флаг; при `active == true` немедленно `stopAll()` |
| `onVoiceAvailabilityChanged({required bool available})` | `TablePage` — по результату `SpeechSynthesizer.isAvailableFor(languageTag)` | Запоминает флаг; при `false` — `stopAll()` |
| `stopAll()` | `TablePage` (тап по персонажу — новый цикл; `AppLifecycleState.paused`/`inactive`) и сам Cubit | Чистит очередь, зовёт `synthesizer.stop()`, сбрасывает `speakingCharacterId` |
| `close()` | `TablePage.dispose` | `stopAll()` + отписка от `watch()` |

Гейт `soundEnabled` Cubit получает сам из `SettingsRepository.watch()` — не через параметр метода:
FR-008 требует остановки в момент выключения тумблера, даже если экран в это время не
перестраивается.

---

## 3. Инварианты

| # | Инвариант | Из |
|---|---|---|
| V1 | В любой момент времени произносится не более одной реплики; следующая начинается строго после завершения предыдущей | FR-005, SC-003 |
| V2 | Порядок произнесения = порядок вызовов `enqueue` | FR-005 |
| V3 | `enqueue` во время произнесения не прерывает текущую реплику | US3.2 |
| V4 | Беззвучный режим проверяется непосредственно перед каждым `speak`, а не при постановке в очередь | FR-011b |
| V5 | После `stopAll()` ни одна ранее поставленная реплика не прозвучит | FR-009, FR-010 |
| V6 | Любой `Result.failure` от синтезатора не эмитит ошибку наружу: реплика молча пропускается, обработка очереди продолжается | FR-012, SC-006 |
| V7 | После каждого `await` проверяется `isClosed` перед `emit` | принцип VI, `lessons-learned.md` |
| V8 | Cubit ничего не пишет в БД и не трогает `TableCubit` | Assumptions спеки |
| V9 | Выключение `soundEnabled` во время произнесения чистит очередь целиком, а обратное включение ничего не доигрывает | FR-008 |
| V10 | Остановка по жизненному циклу не запоминает прерванное: возврат на передний план не возобновляет ни реплику, ни очередь | FR-011 |
| V11 | Cubit существует только в поддереве `/table` — ни один другой экран (в т.ч. Дневник) его не создаёт и не озвучивает реплики | FR-017 |

---

## 4. Проводка в `TablePage` (что меняется в существующем коде)

| Место | Изменение |
|---|---|
| `_TablePageState.initState`/`dispose` | Создание/закрытие `TableVoiceCubit` рядом с `TableCubit`; `BlocProvider.value` над деревом |
| `_TablePageState.didChangeAppLifecycleState` | К существующему `flushDayText` на `paused` добавляется `stopAll()` на `paused` **и** `inactive` (FR-011, research.md R11) |
| `_TablePageState.build` | Чтение `MediaQuery.accessibleNavigationOf(context)` → `onScreenReaderChanged`; проверка `isAvailableFor(Localizations.localeOf(context))` → `onVoiceAvailabilityChanged` |
| `_RoundTableState.didUpdateWidget` | Там же, где выставляется `_revealing[id] = true` для нового `CharacterSlotSpoken(restored: false)`, вызывается `enqueue(...)` |
| `_RoundTableState._seatFor` (тап) | Перед `widget.onCharacterTap(character.id)` — `stopAll()` (новый цикл, FR-010) |
| `_RoundTableState._seatFor` (визуал) | `CharacterVisualState.speaking`, если `isRevealing` **или** `speakingCharacterId == character.id` (FR-016, FR-016a) |

`TableCubit`, `TableState`, `SpeakingBubble`, `CharacterAvatar` не меняются.

---

## 5. Тесты (`test/presentation/table_voice_cubit_test.dart`)

Обязательный минимум для `bloc_test` (принцип VI, цель >70%):

1. Одна реплика при открытых гейтах → `speakingCharacterId` выставляется и сбрасывается.
2. Две реплики подряд → второй `speak` вызван строго после завершения первого (V1, V2).
3. `enqueue` во время произнесения → текущая не прервана (V3).
4. `stopAll()` во время произнесения → `synthesizer.stop()` вызван, очередь пуста, вторая реплика
   не прозвучала (V5).
5. `soundEnabled: false` из `watch()` → `enqueue` ничего не делает; переход `true → false` во
   время произнесения → `stopAll()` (FR-006, FR-008).
6. `onScreenReaderChanged(active: true)` → остановка и запрет постановки (FR-014).
7. `onVoiceAvailabilityChanged(available: false)` → то же (FR-012).
8. `silentModeProbe.isSilent() == true` → `speak` не вызывается, но очередь продолжает
   обрабатываться (V4).
9. `speak` возвращает `failure` → следующая реплика всё равно произносится, наружу ничего не
   эмитится (V6).
10. `close()` во время произнесения → нет `emit` после закрытия (V7).
