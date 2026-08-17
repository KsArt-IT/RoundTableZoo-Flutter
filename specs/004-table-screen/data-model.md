# Phase 1 — Data Model: Экран «Стол»

**Feature**: `specs/004-table-screen` | **Date**: 2026-08-17

Схема БД **не меняется**: `day_entries`, `character_reactions`, `user_settings` уже созданы фазой
001 (`project/architecture/database-tables.md`). Новых таблиц нет, `schemaVersion` не поднимается.
Ниже — только то, что добавляется этой фичей, и то, как существующие сущности используются.

---

## 1. Существующие сущности (переиспользуются как есть)

| Сущность | Файл | Что делает Стол |
|---|---|---|
| `DayEntry` | `domain/entities/day_entry.dart` | читает запись текущего дня, пишет `moodScore`/`dayText` через `saveTodayEntry` |
| `CharacterReaction` | `domain/entities/character_reaction.dart` | создаёт по одной на каждый полученный ответ (`addReaction`) |
| `MoodScore` | `domain/value_objects/mood_score.dart` | значение шкалы 1..5 |
| `ReactionTone` | `domain/value_objects/reaction_tone.dart` | тон реплики; неизвестное значение → `neutral` |
| `DayKey` | `domain/entities/day_key.dart` | текущий день, приходит из `CurrentDayCubit` |
| `UserSettings` | `domain/entities/user_settings.dart` | читает `enabledCharacterIds`, `installId` |

**Инварианты, действующие на этом экране:**

- `moodScore` обязателен; реакция не может существовать без записи дня (FK
  `character_reactions.dayEntryId`) — отсюда FR-014 «сначала эмодзи, потом тап».
- «Не более одной записи на день» обеспечивается транзакцией `saveTodayEntry`, а не индексом.
- У одного персонажа за день допустимо **несколько** реакций (FR-021a); на Столе показывается
  последняя по `createdAt`, в Дневнике — все.
- `dayText` ≤ `AppConstants.maxDayTextLength` (2000), пустая строка нормализуется в `null`
  (`Validators.dayText`).
- `intensity` ∈ [0.0, 1.0] (`Validators.intensity`) — проверяется в `addReaction`.

---

## 2. Новая доменная сущность: `Character`

`domain/entities/character.dart` — статическая конфигурация персонажа, **не таблица БД**.
Загружается из ассета (см. `contracts/character-config.md`).

| Поле | Тип | Правила |
|---|---|---|
| `id` | `String` | непустой, уникальный в каталоге; совпадает с `character_reactions.characterId` и элементами `enabledCharacterIds` |
| `name` | `String` | отображаемое имя, непустое |
| `colorHex` | `int` | ARGB, разобранный из строки вида `#7B8B6F` при парсинге |
| `idleAnimation` | `String?` | путь к Lottie; `null` → статичный аватар без ошибки |
| `talkAnimation` | `String?` | то же для состояния «говорит» |
| `fallbackReply` | `String` | заготовленная реплика (FR-027, FR-027b), непустая |
| `maxReplyLength` | `int` | > 0; используется как ожидание длины, не как обрезание чужого текста |

Поля `systemPrompt`, `voicePitch`, `voiceRate` из `03-ai-integration.md` в клиент **не попадают**:
промпт живёт на прокси (принцип V), озвучка вне скоупа. `Character` не хранит состояние — только
конфигурацию.

### `CharacterCatalog`

`data/datasources/character_catalog.dart` — загрузка и кэш каталога.

- `Future<Result<List<Character>>> load()` — парсит ассет один раз, дальше отдаёт кэш.
- Порядок элементов ассета = порядок рассадки за столом.
- Персонаж без пары в `enabledCharacterIds` не рисуется; `characterId` из БД, которого нет в
  каталоге (удалённый зверь), не ломает восстановление — соответствующая реплика пропускается.
- Ошибка разбора → `SerializationFailure`; экран показывает состояние ошибки, шкала настроения при
  этом остаётся рабочей.

---

## 3. Состояние экрана: `TableState`

`presentation/table/cubit/table_state.dart` — Freezed sealed по контракту принципа II.

```text
TableState
├── initial()
├── loading()
├── loaded(TableData data)
└── error(AppFailure failure)      // не удалось загрузить день/каталог
```

### `TableData`

| Поле | Тип | Смысл |
|---|---|---|
| `dayKey` | `DayKey` | день, к которому относится всё остальное |
| `entryId` | `int?` | `null`, пока запись дня не создана (настроение не выбрано) |
| `moodScore` | `MoodScore?` | выбранная оценка; `null` = не выбрана |
| `dayText` | `String` | текущий черновик (может быть не сохранён — см. `isDayTextDirty`) |
| `isDayTextDirty` | `bool` | есть несохранённые изменения текста (дебаунс R10) |
| `characters` | `List<Character>` | включённые персонажи в порядке рассадки |
| `slots` | `Map<String, CharacterSlot>` | состояние каждого персонажа, ключ — `Character.id` |
| `readOnly` | `bool` | режим хранилища «только чтение» (FR-032) |

Производные значения (геттеры, не поля — во избежание рассинхрона):
`canRequestReaction = moodScore != null && dayText.trim().isNotEmpty && !readOnly`.

### `CharacterSlot`

Состояние одного персонажа за столом — sealed:

| Вариант | Когда | Что показывает UI |
|---|---|---|
| `idle()` | ещё не спрашивали | покой, бабла нет |
| `loading()` | запрос в полёте | индикация ожидания (FR-016) |
| `spoken(CharacterReaction reaction, {bool stale, bool restored, bool persistFailed})` | ответ получен или восстановлен | бабл с репликой, метка «уже отвечал» |

Поля `spoken`:

- `reaction` — уже сохранённая сущность (несёт `reply`, `tone`, `intensity`, `isFallback`).
- `stale` — реплика относится к прежней версии текста (FR-023); снимается новым ответом
  (FR-023a); при восстановлении после перезахода всегда `false` (FR-023b).
- `restored` — реплика поднята из БД, а не получена только что: бабл показывается сразу целиком,
  без эффекта проговаривания (FR-003b).

- `persistFailed` — реплика получена, но не сохранена (FR-021c): бабл показывается, пользователь
  получает сообщение, при следующем `load()` такая реплика не восстановится.

Отдельного варианта «ошибка» у слота нет намеренно: `invalidResponse`/`timeout` дают
`spoken(isFallback: true)`, а `network`/`rateLimited`/`aiDisabled` — не состояние слота, а
одноразовый сигнал (см. ниже), после которого слот **возвращается ровно в то состояние, в котором
был до тапа** (FR-029a): с прежней репликой, если она была, иначе в покой.

`isFallback` из `reaction` — не только флаг хранения: бабл показывает по нему ненавязчивую пометку
и отражает её в семантике (FR-027c).

### Одноразовые сигналы

`Stream<AppFailure> get failures` на `TableCubit` — по образцу `SettingsCubit._failures`:
несохранение отметки, `network`/`rateLimited`/`aiDisabled`. Экран показывает их inline рядом со
столом (FR-029: не глобальный тост), сам Cubit в `state.error` из-за них не уходит — стол обязан
остаться рабочим для отметки настроения.

---

## 4. Переходы состояний

**Загрузка экрана** (`load()`):

```
initial → loading → loaded(entry?, реакции последних по каждому персонажу)
                 └→ error(failure)        // каталог/БД недоступны
```

**Выбор эмодзи**: `loaded` → `saveTodayEntry(mood, dayText)` → `loaded(entryId, moodScore)`.
При неудаче — состояние не меняется, ошибка уходит в `failures`.

**Ввод текста**: `loaded(isDayTextDirty: true)` → (пауза 1 с | уход с экрана | перед запросом) →
`saveTodayEntry` → `isDayTextDirty: false`. Если `moodScore == null`, сохранение откладывается до
первого выбора эмодзи (FR-008c).

**Правка текста при наличии реплик**: все `spoken` слоты получают `stale: true`.

**Запрос реакции** (`requestReaction(characterId)`):

```
slot: idle|spoken → loading
   ├─ success           → addReaction → spoken(reaction, stale: false, restored: false)
   │                      └─ addReaction упал → spoken(..., persistFailed: true) + failures.add
   ├─ invalidResponse   → addReaction(fallback, isFallback: true) → spoken(...)
   ├─ timeout           → то же, что invalidResponse (FR-027b)
   └─ network|rateLimited|aiDisabled → слот возвращается в прежнее состояние + failures.add(...)
```

Устаревшее поколение (R6) не производит ни `emit`, ни `addReaction`. Закрытый Cubit (уход с
экрана) — тоже: ответ отбрасывается и не сохраняется (FR-021d).

**Смена дня**: `loaded` → `_flushDayText()` → `loading` → `load()` для нового `DayKey`.

---

## 5. Что этой фичей НЕ создаётся

- Новые таблицы, колонки и миграции.
- Новые методы `DiaryRepository`/`SettingsRepository` — хватает существующих
  (`saveTodayEntry`, `entryForDay`, `reactionsFor`, `addReaction`, `watch`).
- Хранение `stale`/`restored` в БД: это только состояние экрана (FR-023b).
