# Contract — `TableCubit`

**Feature**: `specs/004-table-screen` | Состояния и переходы: `data-model.md` §3–4.

Публичный API экранного Cubit-а — то, что вызывает `TablePage`, и то, что проверяют `bloc_test`.

## 1. Конструктор и время жизни

```dart
@injectable                       // factory, не lazySingleton (research.md R5)
class TableCubit extends Cubit<TableState> {
  TableCubit({
    required DiaryRepository diaryRepository,
    required SettingsRepository settingsRepository,
    required AiReactionRepository aiReactionRepository,
    required CharacterCatalog characterCatalog,
    required AppClock clock,
    required StorageMode storageMode,
  });
}
```

- Никаких других Cubit-ов среди зависимостей (принцип I).
- Свежий инстанс на каждый вход на `/table`; `close()` сбрасывает несохранённый текст в БД и
  отменяет подписки/таймер.
- Время — только `AppClock`; `DateTime.now()` в Cubit-е запрещён (принцип IV).

## 2. Методы

| Метод | Контракт |
|---|---|
| `Future<void> load()` | Загружает каталог, настройки, запись дня и последние реплики. `initial → loading → loaded \| error`. Идемпотентен: повторный вызов не дублирует подписки. |
| `Future<void> setMood(MoodScore score)` | Сохраняет отметку (`saveTodayEntry` вместе с текущим текстом), обновляет `entryId`/`moodScore`. При неудаче состояние не меняется, ошибка уходит в `failures`. В `readOnly` не вызывает репозиторий. |
| `void onDayTextChanged(String text)` | Обновляет черновик, ставит `isDayTextDirty: true`, перезапускает дебаунс-таймер (1 с). При наличии `spoken`-слотов помечает их `stale: true` (FR-023). |
| `Future<void> flushDayText()` | Принудительное сохранение текста. Зовётся из `close()`, при `AppLifecycleState.paused` и перед `requestReaction`. Ничего не делает, если `!isDayTextDirty` или `moodScore == null`. |
| `Future<void> requestReaction(String characterId)` | Основной сценарий US2/US3 — см. §3. |
| `void onDayChanged(DayKey key)` | `flushDayText()` → сброс состояния → `load()` для нового дня (FR-006). |
| `Stream<AppFailure> get failures` | Одноразовые сигналы: отказ сохранения, `network`/`rateLimited`/`aiDisabled`. Broadcast, закрывается в `close()`. |

Предусловия `requestReaction` (FR-014): при `moodScore == null`, пустом `dayText` или
`readOnly` метод не отправляет запрос и публикует в `failures` соответствующий
`ValidationFailure`/`DatabaseFailure(storageReadOnly)` — «молча проигнорировать тап» запрещено.

## 3. Алгоритм `requestReaction`

```dart
Future<void> requestReaction(String characterId) async {
  // 0. предусловия (см. выше) + flushDayText()
  final generation = (_generation[characterId] ?? 0) + 1;
  _generation[characterId] = generation;

  emit(/* slot: loading */);
  final result = await _aiReactionRepository.requestReaction(...);

  if (isClosed) return;                              // порядок обязателен
  if (_generation[characterId] != generation) return; // устаревший ответ: ни emit, ни запись в БД

  // success            → addReaction → slot: spoken(stale: false, restored: false)
  // invalidResponse|timeout → addReaction(fallback, isFallback: true) → slot: spoken(...)
  // network|rateLimited|aiDisabled → slot: прежнее состояние + failures.add(failure)
}
```

Инварианты, которые обязаны проверяться тестами:

1. `isClosed` проверяется **раньше** сверки поколения и любого `emit`.
2. Устаревший ответ не вызывает `addReaction` — иначе в БД остаётся реплика, которой не было на
   экране (FR-020).
3. Запросы к разным персонажам не сериализуются: два `requestReaction` подряд дают два
   `loading`-слота одновременно (FR-019).
4. Заготовленная реплика сохраняется так же, как настоящая, но с `isFallback: true` (FR-021).
5. Отказ `addReaction` не «съедает» реплику: слот получает `persistFailed: true`, ошибка уходит в
   `failures` (FR-021c).
6. `network`/`rateLimited`/`aiDisabled` возвращают слот в состояние **до** тапа, а не в покой
   (FR-029a) — тест обязан проверять случай «у персонажа уже была реплика».

## 4. Обязательное покрытие (`test/presentation/table_cubit_test.dart`)

Целевое покрытие нового Cubit — >70% (принцип VI). Минимальный набор `bloc_test`:

- `load()`: пустой день; день с записью; день с записью и репликами (восстановление последней на
  персонажа, `restored: true`); ошибка каталога → `error`.
- `setMood`: создание записи; обновление существующей; отказ репозитория → `failures`, состояние
  не меняется; `readOnly` → репозиторий не вызывается.
- Текст: дебаунс через `fake_async` (один вызов `saveTodayEntry` на серию правок); `flushDayText`
  из `close()`; текст до выбора эмодзи сохраняется первым `setMood` (FR-008c); правка помечает
  слоты `stale`.
- `requestReaction`: успех; каждый из пяти кодов `AiProxyFailure`; два тапа по одному персонажу
  (побеждает последний, первый не пишется в БД); тапы по двум персонажам параллельно;
  `isClosed` после `await`; предусловия (нет настроения / пустой текст / `readOnly`).
- `onDayChanged`: сброс состояния и повторная загрузка; несохранённый текст уходит в **старый**
  день.

## 5. Что Cubit НЕ делает

- Не форматирует и не переводит текст реплики (FR-022).
- Не знает про HTTP-коды и `DioException` — только `AppFailure`.
- Не отвечает за эффект проговаривания (это виджет — research.md R8) и не эмитит состояния
  покадрово.
- Не читает `DateTime.now()`, `SharedPreferences`, `rootBundle` напрямую — только через
  инжектированные зависимости.
