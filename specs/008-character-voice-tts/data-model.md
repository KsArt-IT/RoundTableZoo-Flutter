# Phase 1 — Data Model: Озвучка реплик персонажей

Фича не добавляет ни одной таблицы БД, ни одной колонки и ни одной миграции. Всё ниже —
конфигурация ассета, доменное значение и состояние экранного Cubit-а.

---

## 1. `CharacterVoice` (новое, `domain/value_objects/character_voice.dart`)

Тембр одного персонажа. Freezed value-object, чистый Dart.

| Поле | Тип | Диапазон | Смысл |
|---|---|---|---|
| `pitch` | `double` | 0.5 … 2.0 | Высота голоса; 1.0 — обычная |
| `rate` | `double` | 0.0 … 1.0 | Темп речи; 0.5 — обычный на обеих платформах |

**Правила валидации**: значения вне диапазона зажимаются (`clamp`) при парсинге, а не роняют
загрузку каталога — сломанный конфиг деградирует до звучания, а не до пустого стола
(та же логика, что у `emoji` в `contracts/character-config.md` фичи 004).

**Значение по умолчанию**: `CharacterVoice.neutral` — `pitch: 1.0`, `rate: 0.5`. Используется,
когда у персонажа в JSON нет `voice`.

---

## 2. `Character` (существующее, `domain/entities/character.dart`) — расширение

Добавляется одно поле:

| Поле | Тип | Обязательность | Смысл |
|---|---|---|---|
| `voice` | `CharacterVoice` | обязательное в entity, необязательное в JSON (default `neutral`) | Тембр персонажа (FR-003) |

Поле-значение, а не два плоских `voicePitch`/`voiceRate`: одна причина существования — один тип
(правило DRY из `CLAUDE.md`).

Остальные поля (`id`, `name`, `emoji`, `colorHex`, `fallbackReply`, `maxReplyLength`,
`idleAnimation`, `talkAnimation`) не меняются.

---

## 3. `assets/characters/characters.json` — расширение

Каждый элемент массива получает необязательный объект `voice`. Полный контракт и стартовые
значения — [contracts/character-voice-config.md](./contracts/character-voice-config.md).

---

## 4. `VoiceUtterance` (новое, внутренний тип `TableVoiceCubit`)

Один элемент очереди произнесения (сущность «Очередь произнесения» из спеки).

| Поле | Тип | Смысл |
|---|---|---|
| `characterId` | `String` | Чей голос и чей аватар подсвечивать (FR-016) |
| `text` | `String` | Полный текст реплики — `CharacterReaction.reply`, включая `fallbackReply` |
| `voice` | `CharacterVoice` | Тембр на момент постановки в очередь |
| `languageTag` | `String` | Язык интерфейса на момент постановки в очередь (FR-002 + краевой случай смены языка) |

Порядок в очереди — порядок постановки, то есть порядок появления баблов (FR-005). Дубликаты по
`characterId` возможны и допустимы (переспрос — Assumptions спеки).

---

## 5. `TableVoiceState` (новое, Freezed)

Единственное состояние (не sealed-иерархия `initial/loading/loaded/error`): у озвучки нет ни
загрузки, ни пользовательской ошибки — отказ синтеза по FR-012 неотличим от «нечего говорить».

| Поле | Тип | Смысл |
|---|---|---|
| `speakingCharacterId` | `String?` | Кто говорит прямо сейчас; `null` — тишина. Единственное, что читает UI (FR-016) |
| `queueLength` | `int` | Длина очереди ожидающих; нужна тестам и отладке, UI её не показывает |

Внутреннее (не в состоянии): сама очередь `List<VoiceUtterance>`, флаг «идёт обработка»,
последние известные `soundEnabled`, `screenReaderActive`, `languageTag`.

**Переходы**:

| Из | Событие | В |
|---|---|---|
| `speakingCharacterId == null`, очередь пуста | `enqueue(u)` при открытых гейтах | `speakingCharacterId = u.characterId` |
| говорит A | `enqueue(u)` | очередь +1, `speakingCharacterId` не меняется (FR-005, US3.2) |
| говорит A | завершение произнесения | следующий из очереди или `null` |
| любое | `stopAll()` | `speakingCharacterId = null`, `queueLength = 0` |
| любое | `enqueue` при закрытом гейте | без изменений (реплика не ставится в очередь) |

**Гейты постановки в очередь** (все должны быть открыты): `soundEnabled == true` (FR-006),
озвучка доступна (FR-012), скринридер выключен (FR-014), устройство не в беззвучном режиме
(FR-011b — проверяется непосредственно перед произнесением, а не при постановке, т.к. режим
может смениться, пока реплика ждёт очереди).

---

## 6. `VoiceAvailability` (новое, `presentation/settings/cubit/settings_state.dart`)

Причина, по которой тумблер озвучки недоступен — то, что показывает `SoundSection` (FR-013).

| Значение | Когда | Пояснение под тумблером |
|---|---|---|
| `available` | движок есть, голос для языка интерфейса есть, скринридер выключен | обычный `settingsSoundHint` |
| `noVoiceForLanguage` | движок ответил, голоса для языка интерфейса нет; либо движок недоступен | «нет движка синтеза речи или голоса для этого языка» |
| `screenReaderActive` | включён TalkBack/VoiceOver | «реплики читает скринридер» |

`screenReaderActive` имеет приоритет над `noVoiceForLanguage` — он объясняет более понятную
пользователю причину.

**Инвариант (FR-013a)**: `VoiceAvailability` влияет только на `onChanged` и подпись
`SwitchListTile`. Хранимое значение `user_settings.soundEnabled` при этом не пишется никогда —
`SettingsCubit.setSoundEnabled` вызывается исключительно из тапа пользователя.

---

## 7. Что осталось неизменным

- `user_settings.soundEnabled` — существующая колонка, новых настроек нет (Assumptions спеки).
- `TableState`/`TableData`/`CharacterSlot` — не меняются ни на поле (research.md R5, R9).
- `CharacterReaction`, `day_entries`, `character_reactions` — не меняются; озвучка ничего не пишет.
- `AppFailure` — новых кодов нет: отказ синтеза не становится пользовательской ошибкой
  (см. Complexity Tracking в `plan.md`).
