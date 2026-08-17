# Phase 0 — Research: Экран «Стол»

**Feature**: `specs/004-table-screen` | **Date**: 2026-08-17

Решения, снимающие неизвестные из Technical Context `plan.md`. Формат каждого пункта:
Decision → Rationale → Alternatives considered.

---

## R1. HTTP-клиент для ai-proxy

**Decision**: добавить `dio` (в `~/.pub-cache` уже лежит `dio-5.10.0`) и завести
`core/network/ai_proxy_client.dart` — тонкую обёртку над `Dio` с базовым URL, таймаутами и
JSON-декодированием. Никаких интерцепторов подлинности в этой фазе (Play Integrity отложен —
Clarifications Q1).

**Rationale**: `architecture-full.md` прямо называет `core/network/ai_proxy_client.dart` на dio;
интерцепторы понадобятся в фазе прокси (Integrity-токен, ретраи), и dio даёт для них штатное
место. `BaseOptions.connectTimeout`/`receiveTimeout` закрывают FR-027a без ручного гонщика
таймеров в репозитории.

**Alternatives considered**: пакет `http` (есть в кэше) — меньше веса, но интерцепторы пришлось бы
писать руками ровно там, где следующая фаза их и потребует; `HttpClient` из `dart:io` — ломает
кроссплатформенность и тестируемость.

---

## R2. Откуда берётся адрес прокси

**Decision**: `--dart-define=PROXY_BASE_URL=...`, читается один раз через
`String.fromEnvironment` в `core/network/ai_proxy_config.dart`. Пустое значение (значение по
умолчанию) означает «прокси не сконфигурирован» и переводит DI на заглушку из R14 — но **только в
debug/profile**: в release пустой адрес обязан ронять запуск с внятной ошибкой (SC-012), иначе
собранная сборка молча уедет в Store с заглушкой вместо AI.

**Rationale**: так записано в `architecture-full.md`; `--dart-define` попадает в бинарь на этапе
сборки и не требует ассета, который надо не забыть исключить из репозитория. Пустая строка как
переключатель на заглушку даёт рабочий `flutter run` без каких-либо аргументов — важное свойство,
пока прокси не существует.

**Alternatives considered**: `flutter_dotenv` (уже в зависимостях) — файл `.env` пришлось бы
класть в ассеты и держать в `.gitignore`, что даёт лишний способ «собрать без конфига и не
заметить»; захардкоженный URL — исключено (адрес отличается между dev и prod).

---

## R3. Шаринг реплики

**Decision**: добавить `share_plus` и звать его из `presentation/table/` через тонкий сервис
`core/sharing/share_service.dart` (интерфейс + реализация), чтобы Cubit оставался тестируемым, а
будущий CSV-экспорт Дневника переиспользовал тот же сервис.

**Rationale**: `04-requirements-diary.md` прямо требует не заводить второй механизм шаринга ради
DRY. Абстракция нужна ещё и потому, что `share_plus` дёргает платформенный канал — в widget-тестах
он обязан подменяться (урок `lessons-learned.md` про `flutter_local_notifications`).

**Alternatives considered**: звать `Share.share` прямо из виджета — быстрее, но повторяет ровно ту
ошибку, из-за которой widget-тесты уже падали с `MissingPluginException`.

**Внимание при реализации**: в `~/.pub-cache` сейчас `share_plus-10.1.4` со статическим
`Share.share(...)`; более новые мажорные версии перешли на `SharePlus.instance.share(ShareParams)`.
Версию брать из `app/pubspec.lock` после `flutter pub add` и сверять API с исходником в кэше, а не
по памяти.

---

## R4. Формат и загрузка конфига персонажей

**Decision**: один ассет `assets/characters/characters.json` — JSON-массив персонажей в порядке
рассадки за столом. Загружается `CharacterCatalog` (`data/datasources/character_catalog.dart`)
через `rootBundle.loadString`, парсится в `Character` (`domain/entities/character.dart`),
кэшируется в памяти на время работы приложения.

**Rationale**: `03-ai-integration.md` описывает поля персоны, но не требует ровно одного файла на
персонажа; один файл даёт детерминированный порядок рассадки, один разбор и одну точку отказа
вместо перебора `AssetManifest`. Ростер MVP — 4 записи, добавление зверя остаётся правкой
единственного JSON без нового кода.

**Alternatives considered**: `assets/characters/<id>.json` по файлу на персонажа (буквальное
чтение PRD) — требует либо жёсткого списка id в коде (дубль источника правды), либо чтения
`AssetManifest.json`, что медленнее и сложнее тестируется; конфиг в Dart-константах — правка
ростера превращается в правку кода вопреки «просто новый конфиг, без новой логики».

---

## R5. Границы и время жизни `TableCubit`

**Decision**: `TableCubit` — **screen-scoped** `@injectable` factory (как `SettingsCubit`), а не
`@lazySingleton`. Он владеет: текущей записью дня, черновиком текста, картой слотов персонажей и
generation-счётчиком. Глобальные `CurrentDayCubit`/`AppSettingsCubit` он не импортирует —
`TablePage` слушает `CurrentDayCubit` через `BlocListener` и зовёт `TableCubit.onDayChanged(key)`.

**Rationale**: принцип I конституции запрещает Cubit-ам импортировать друг друга; экранный factory
не воспроизводит трёхступенчатую поломку widget-тестов из `lessons-learned.md` (переиспользование
закрытого `@lazySingleton` между тестами, висящий Drift-таймер).

**Alternatives considered**: глобальный `TableCubit`, чтобы состояние переживало переключение
вкладок, — не нужен: `StatefulShellRoute.indexedStack` и так сохраняет ветку живой, а восстановление
после холодного старта решается чтением из БД (FR-003a).

---

## R6. Генерация-счётчик и параллельные тапы

**Decision**: `Map<String, int> _generation` — по счётчику на `characterId`, как в
`architecture-full.md`. После `await`: сначала `if (isClosed) return;`, затем сверка поколения,
затем `emit`. Устаревший ответ не пишется в БД (FR-020) — сохранение идёт **после** проверки
поколения, а не в момент получения ответа.

**Rationale**: порядок «isClosed → generation → emit/persist» — единственный, при котором
устаревший ответ не оставляет следа ни в UI, ни в хранилище; иначе FR-020 нарушается именно на
записи, а не на отображении.

**Alternatives considered**: отмена запроса через `CancelToken` dio — не заменяет счётчик (гонка
остаётся между «ответ уже в пути» и отменой) и добавляет состояние, которое всё равно надо
сверять; оставляю `CancelToken` фазе прокси как оптимизацию трафика.

---

## R7. Таймаут и таксономия ошибок AI

**Decision**: новый `AiProxyFailure extends AppFailure` в `core/errors/app_failure.dart` с кодами
`network`, `rateLimited`, `aiDisabled`, `invalidResponse`, `timeout`. Маппинг HTTP → код живёт
**только** в `data/repositories/ai_reaction_repository_impl.dart`:
`429 → rateLimited`, `503 → aiDisabled`, `422 → invalidResponse`, любой иной статус/разбор →
`invalidResponse`, `DioExceptionType.connectionError/connectionTimeout` → `network`,
`receiveTimeout`/`Future.timeout` → `timeout`. Клиентский таймаут — 15 секунд
(`AppConstants.aiRequestTimeout`).

**Rationale**: FR-024…FR-027b требуют разного текста на `network`/`rateLimited`/`aiDisabled` и
одинакового поведения на `invalidResponse`/`timeout` (заготовленная реплика). Разделение кодов при
общем поведении двух из них оставляет возможность отличить их в логах, не плодя UI-веток.
`localizedMessage` реализуется по образцу `DatabaseFailure`/`ValidationFailure`.

**Alternatives considered**: переиспользовать существующие `NetworkFailure`/`TimeoutFailure` — они
не несут кода `rateLimited`/`aiDisabled` и размывают правило «HTTP-коды видит только репозиторий».

---

## R8. Эффект проговаривания реплики

**Decision**: виджет `SpeakingBubble` с `AnimationController`, длительность =
`min(text.length * 25ms, 4s)` — верхняя граница закреплена требованием FR-017b; отображается
`text.substring(0, progress)`. **Короткий** тап по баблу завершает контроллер
(`controller.value = 1`), **долгое нажатие** вызывает шаринг (FR-017a, FR-030) — два жеста на одном
`GestureDetector` (`onTap`/`onLongPress`), плюс `SemanticsAction` «поделиться» для программ чтения
с экрана. Восстановленные реплики (FR-003b) и `MediaQuery.disableAnimationsOf(context) == true`
(FR-033a) показывают текст сразу целиком.

**Rationale**: эффект чисто презентационный — держать его в виджете, а не в состоянии Cubit-а,
значит не гонять `emit` десятки раз в секунду и не ломать `bloc_test` покадровыми состояниями.
Учёт «уменьшить движение» — требование доступности из `07-non-functional.md`.

**Alternatives considered**: посимвольные `emit` из Cubit-а — шум в тестах и лишние перестроения;
готовые пакеты анимации текста — новая зависимость ради тридцати строк.

---

## R9. Раскладка круглого стола

**Decision**: `LayoutBuilder` + `Stack` с позиционированием по тригонометрии:
`angle = -pi/2 + 2*pi*i/n`, радиус = `min(w, h)/2 - avatarRadius - padding`. Число персонажей
1..6. Каждый аватар — `Semantics(button: true, label: '<имя>, <состояние>')` поверх
`SizedBox(width/height: AppConstants.minTapTargetDp * k)`.

**Rationale**: `02-requirements-table.md` прямо называет `Stack` + тригонометрию. Один персонаж —
вырожденный случай (центр окружности сверху), раскладка не требует особой ветки.

**Alternatives considered**: `Flow`/кастомный `MultiChildLayoutDelegate` — гибче, но дороже в
чтении и тестировании; сетка вместо круга — противоречит самой идее «круглого стола».

**Проверка семантики**: обёртка `Semantics` поверх кастомного `GestureDetector` корректна (в
отличие от `ListTile`-подобных виджетов из `lessons-learned.md`, которые строят свою границу
семантики) — но всё равно проверяется тестом `meetsGuideline(labeledTapTargetGuideline)`.

---

## R10. Автосохранение текста дня

**Decision**: `Timer` на 1 секунду внутри `TableCubit.onDayTextChanged`, перезапускаемый на каждое
изменение; принудительный сброс (`_flushDayText`) — в `close()`, при `AppLifecycleState.paused` и
перед отправкой запроса реплики. Текст, набранный до выбора настроения, живёт в состоянии Cubit-а и
уходит в БД первым же `saveTodayEntry` (FR-008c).

**Rationale**: `saveTodayEntry` пишет `moodScore` и `dayText` вместе (см. комментарий в
`DiaryRepositoryImpl`), поэтому «сохранить только текст» без оценки физически невозможно — отсюда и
формулировка FR-008c. Дебаунс тестируется `fake_async` (уже в dev-зависимостях).

**Alternatives considered**: писать на каждый символ (D в Q5) — десятки транзакций на абзац;
сохранять только по потере фокуса — теряет текст при аварийном закрытии с активным полем.

---

## R11. Восстановление реплик при открытии

**Decision**: `TableCubit.load()` — `entryForDay(today)` → при наличии записи
`reactionsFor(entry.id)` → группировка по `characterId`, берётся последняя по `createdAt`
(датасорс уже сортирует `ASC`, значит `.last`). Восстановленные слоты помечаются
`restored: true` — только для того, чтобы бабл не проигрывал эффект проговаривания (FR-003b).

**Rationale**: не требует новых методов репозитория и новых запросов к БД сверх двух уже
существующих; правило «последняя по времени» совпадает с FR-021b и с тем, что Дневник видит все
варианты.

**Alternatives considered**: новый метод `latestReactionsFor(dayEntryId)` с группировкой в SQL —
экономия на 4–20 строках, не оправдывающая расширение контракта репозитория.

---

## R12. Поведение в режиме «только чтение»

**Decision**: `TableCubit` получает `StorageMode` через уже существующий `AppSession`
(конструкторный параметр, значение читается из DI). При `readOnly`: сохранение отметки не
вызывается (в этом режиме зарегистрирован `UnavailableDiaryRepository`, любой вызов всё равно
вернул бы `storageReadOnly`), тап по персонажу не инициирует сетевой запрос, а показывается
inline-объяснение. Баннер режима рисует уже существующий `ShellPage`.

**Rationale**: FR-032 требует не отправлять запрос, результат которого некуда сохранить; знание
«хранилище не пишет» уже есть в приложении, заводить второй источник этого факта нельзя (DRY).

**Alternatives considered**: узнавать про режим по первой неудаче репозитория — пользователь
получил бы ошибку записи после того, как запрос уже ушёл в сеть.

---

## R13. Смена дня при открытом экране

**Decision**: `TablePage` оборачивается `BlocListener<CurrentDayCubit, CurrentDayState>`, который
на смену `DayKey` зовёт `TableCubit.onDayChanged(key)`; тот сбрасывает состояние и перезапускает
`load()`. Перед сбросом выполняется `_flushDayText()`, чтобы текст ушёл в **уходящий** день.

**Rationale**: `CurrentDayCubit` уже вычисляет день по тикам и `dayStartHour`; дублировать эту
логику в `TableCubit` нельзя (принцип IV + DRY).

**Внимание при реализации**: `CurrentDayCubit` — `@lazySingleton`, и с этой фичей он впервые
реально читается в дереве. По уроку из `lessons-learned.md` `test/support/test_app_root.dart`
обязан пересоздавать его на каждый `buildTestAppRoot()` — иначе widget-тесты повторят три
известные поломки (закрытый инстанс, висящий Drift-таймер, отсутствие регистрации).

---

## R14. Заглушка прокси на время разработки

**Decision**: интерфейс `AiProxyClient` (`core/network/`) с двумя реализациями:
`DioAiProxyClient` (боевая) и `StubAiProxyClient` (детерминированные реплики на персонажа,
искусственная задержка ~1.2 с, управляемый сценарий отказа). Выбор — в `injection_module.dart` по
пустому `PROXY_BASE_URL` из R2. Заглушка живёт в `lib/`, а не в `test/`, потому что нужна для
ручного прогона `flutter run`, но никогда не выбирается, когда URL задан.

**Rationale**: без неё US2–US5 нечем демонстрировать до появления прокси, а спека прямо требует
проверять их «против заглушки, воспроизводящей контракт».

**Alternatives considered**: только моки в тестах — тогда экран нельзя ни разу увидеть работающим
до фазы прокси; поднимать локальный фейковый HTTP-сервер — лишняя инфраструктура ради того же
результата.

---

## R15. Шкала настроения

**Decision**: `core/constants/mood_scale.dart` — маппинг `MoodScore.value (1..5)` → эмодзи, ключ
локализованной подписи и семантический цвет. Именно этот файл назван в `database-tables.md`,
поэтому создаётся ровно по указанному пути.

**Rationale**: единственный источник соответствия «оценка → эмодзи/цвет» нужен и Столу, и будущему
графику Дневника; подпись берётся из l10n, чтобы FR-001 (различимость не только цветом) выполнялся
и для программ чтения с экрана.

**Alternatives considered**: держать эмодзи прямо в виджете шкалы — Дневник неизбежно завёл бы
вторую копию.

---

## R16. Новые строки локализации

**Decision**: все новые ключи добавляются в три ARB (`lib/l10n/intl_ru.arb` — шаблон,
`intl_en.arb`, `intl_uk.arb`) одной группой: подписи шкалы настроения, плейсхолдер и счётчик поля
текста, состояния персонажа для семантики, подсказки «сначала выбери эмодзи»/«сначала расскажи о
дне», тексты ошибок AI (`aiNetwork`, `aiRateLimited`, `aiTemporarilyDisabled`), пометка «на прежний
текст», подпись «поделиться», формат текста для шаринга.

**Rationale**: `flutter gen-l10n` падает на несогласованных ARB, поэтому все три файла правятся
в одном шаге; тексты ошибок AI обязаны жить в `AppFailure.localizedMessage`, а не собираться в UI
(принцип II).

**Alternatives considered**: нет — правило фиксировано конституцией.
