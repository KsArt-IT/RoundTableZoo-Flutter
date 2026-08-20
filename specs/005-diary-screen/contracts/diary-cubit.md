# Contract — `DiaryCubit`

**Feature**: `005-diary-screen` | Файл: `app/lib/presentation/diary/cubit/diary_cubit.dart`

Экранный Cubit (`@injectable`-фабрика, свежий инстанс на визит — research.md R14). Зависит только
от абстракций `domain/` и `core/`; **не** импортирует другие Cubit-ы (принцип I).

## 1. Конструктор

```dart
DiaryCubit({
  required DiaryRepository diaryRepository,
  required CharacterCatalog characterCatalog,
  required ExportDiaryToCsv exportDiaryToCsv,
  required ShareService shareService,
});
```

Подписка на `diaryRepository.watchEntriesChanged()` открывается в конструкторе и закрывается в
`close()` (FR-009, research.md R12).

## 2. Публичный API

| Метод | Что делает | Требования |
|---|---|---|
| `Future<void> load()` | `loading` → первая страница + `moodHistory()` + каталог персонажей → `loaded` / `unavailable` / `error` | FR-001, FR-007, FR-008, FR-008a, FR-010, FR-029 |
| `Future<void> retry()` | то же, что `load()`; вызывается кнопкой на баннере ошибки | FR-008a |
| `Future<void> loadMore()` | подгружает следующую страницу по `DiaryPage.nextCursor`; no-op при `loadingMore` или `!hasMore`; сбой пишет `pageFailure`, не меняя состояния экрана | FR-004, FR-004a, FR-004b, FR-004c |
| `Future<void> toggleDay(int entryId)` | инвертирует `expanded` у одного дня — раскрывает и полный текст дня, и реплики; при первом раскрытии подгружает реплики и кэширует | FR-014, FR-015, FR-018 |
| `Future<void> export()` | `exporting: true` → `ExportDiaryToCsv()` → `ShareService.shareCsv(...)` → `exporting: false` | FR-020, FR-023, FR-024, FR-025 |
| `Stream<AppFailure> get failures` | разовые сбои, не отменяющие уже показанный экран (провал экспорта, провал догрузки реплик) | FR-008a |

Состояния и инварианты — [../data-model.md](../data-model.md) §4.

## 3. Правила

- После каждого `await` — `if (isClosed) return;` перед `emit` (принцип VI,
  `lessons-learned.md`).
- `load()`/`retry()` полностью заменяют состояние; `loadMore()`/`toggleDay()` — только
  копируют `DiaryData` с изменённым полем, никогда не сбрасывают чужие поля.
- Курсор и признак «есть ещё» Cubit **не вычисляет**: он берёт `DiaryPage.nextCursor` и
  `DiaryPage.hasMore` как есть (contracts/diary-repository.md §1).
- Дедупликация при слиянии страницы — по `DayKey`, а не по `entryId`: повтор возможен только на
  уровне дня, и у повторной строки того же дня `id` другой (FR-004b, FR-006).
- Ни `moodScore` в списке, ни точка графика, ни значение в CSV не выводятся из
  `CharacterReaction.tone`/`intensity` — эти поля читаются только для отрисовки самой реплики
  (FR-011, SC-007).
- Сигнал `watchEntriesChanged` дебаунсится `AppConstants.diaryRefreshDebounce` и перечитывает
  **только** первую страницу и `moodHistory()`; уже подгруженные старые страницы, набор раскрытых
  дней и загруженные реплики сохраняются (R12).
- Ошибка догрузки реплик одного дня — событие в `failures`, а не переход экрана в `error`: список
  остаётся рабочим.
- Ошибка догрузки **страницы** — `pageFailure` в `DiaryData` (строка с повтором в футере списка), а
  не переход в `error`: уже показанные дни не пропадают (research.md R19). `error` возникает только
  на первой загрузке и на `retry()` (FR-008a).
- `retry()` при повторной неудаче даёт то же состояние `error` — счётчика попыток и нарастающей
  задержки нет.
- Отмена пользователем системного диалога «поделиться» не считается сбоем: `exporting` снимается,
  в `failures` ничего не уходит.
- `AppFailure` с `code == DatabaseFailure.storageReadOnly` → `unavailable`, никогда → `error` и
  никогда → пустой `loaded` (FR-029).
- Cubit не читает `CharacterReaction.tone`/`intensity` ни для списка, ни для графика (FR-011,
  SC-007).
- Текущее время берётся только из `AppClock` внутри `ExportDiaryToCsv` (имя файла); сам Cubit
  `DateTime.now()` не вызывает (принцип IV).

## 4. Тесты (`test/presentation/diary_cubit_test.dart`, `bloc_test`, `mocktail`)

Обязательный минимум (>70% покрытия нового Cubit-а, принцип VI):

1. `load()` на непустой истории → `[loading, loaded]`, порядок дней — новые первыми.
2. `load()` на пустой истории → `loaded` с `days: []`, `hasMore: false`, `canExport == false`.
3. `load()` при `storageReadOnly` → `[loading, unavailable]`.
4. `load()` при `DatabaseFailure(savingError)` → `[loading, error]`; `retry()` → `[loading, loaded]`.
5. `loadMore()` добавляет страницу, не теряя показанных дней и не создавая дублей по `entryId`.
6. Два `loadMore()` подряд без ожидания — один запрос к репозиторию (FR-004b).
7. `loadMore()` при `hasMore: false` — ни одного обращения к репозиторию.
8. Последняя страница (строк меньше `limit`) → `hasMore: false`.
9. `toggleDay()` грузит реплики один раз; повторное сворачивание/раскрытие — без запроса.
10. `toggleDay()` двух разных дней → оба `expanded` одновременно (FR-014).
11. День без реплик после `toggleDay()` → `reactions == []` (а не `null`) — основание для FR-018.
12. Сигнал `watchEntriesChanged` → перечитаны первая страница и `chart`; уже подгруженные старые
    страницы остаются (проверка сохранения раскрытых дней — в тестах US3, где появляется
    `toggleDay`).
13. `export()` при пустой истории — `ShareService` не вызывается.
14. `export()` на непустой истории — `shareCsv` вызван один раз, `exporting` возвращается в `false`.
15. Провал `ExportDiaryToCsv` → событие в `failures`, состояние остаётся `loaded`.
16. `close()` во время `await` любой загрузки — без `emit` после закрытия.
17. Сбой `loadMore()` → `loaded` с непустым `pageFailure`, уже показанные дни на месте; успешный
    повтор очищает `pageFailure`.
18. `retry()` после второй подряд неудачи → снова `[loading, error]`, без накопления состояния.
19. День с несколькими записями (смена `dayStartHour`) на границе страниц не появляется в списке
    дважды — курсор по началу дня, дедупликация по `DayKey` (FR-004b, FR-006).
