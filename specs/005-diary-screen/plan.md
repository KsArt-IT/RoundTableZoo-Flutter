# Implementation Plan: Экран «Дневник»

**Branch**: `005-diary-screen` | **Date**: 2026-08-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-diary-screen/spec.md`

## Summary

Заменить заглушку `/diary` вторым полноценным экраном: постранично подгружаемый список прошлых дней
(дата, эмодзи, текст), график настроения по всей истории с зумом, инлайн-раскрытие реплик
персонажей за день и экспорт истории в CSV через системный «поделиться». Экран — строго читатель:
единственным писателем `day_entries`/`character_reactions` остаётся Стол.

Технически фаза не добавляет ни таблиц, ни миграций, ни сетевых обращений: всё уже лежит в Drift
после фаз 001–004. Добавляются один пакет (`fl_chart`), одна доменная сущность (`MoodChartPoint`),
один usecase (`ExportDiaryToCsv`), один экранный `DiaryCubit` и три метода чтения в
`DiaryRepository` — постраничный `entriesPage`, лёгкая проекция `moodHistory` и батч
`reactionsForEntries`. Существующие методы репозитория и контракты фаз 001–004 не меняются;
`ShareService` расширяется одним методом вместо второго механизма шаринга.

## Technical Context

**Language/Version**: Dart 3.13+ / Flutter (SDK-ограничение `^3.13.0` из `app/pubspec.yaml`)

**Primary Dependencies**: существующие — `flutter_bloc`, `freezed`, `injectable`+`get_it`,
`go_router`, `drift`, `share_plus`, `collection`, `intl` (первое применение `DateFormat` в проекте,
research.md R17); **новая** — `fl_chart: ^1.2.0` (research.md R1; версия уже в `~/.pub-cache`)

**Storage**: Drift, существующие таблицы `day_entries` / `character_reactions`; новых таблиц,
колонок и миграций нет, `schemaVersion` не поднимается

**Testing**: `flutter_test`, `bloc_test`, `mocktail`; репозиторий — на реальной in-memory БД через
`test/support/test_database.dart`, widget — через `test/support/test_app_root.dart`

**Target Platform**: Android (публикуется) + iOS (собирается); из платформенных API — только
системный «поделиться» через уже подключённый `share_plus`

**Project Type**: мобильное приложение, слоистая архитектура (`domain`/`data`/`presentation`)

**Performance Goals**: первая страница списка ≤2 с независимо от объёма истории (SC-001); следующая
страница ≤1 с (SC-008); CSV за год ежедневных записей ≤3 с без подвисания интерфейса (SC-005);
график читаем и отзывчив на истории в годы (FR-010a)

**Constraints**: экран полностью офлайн — ни одного сетевого вызова (FR-003, FR-025, SC-004);
read-only относительно данных Стола (FR-027); тап-таргеты ≥48dp с `Semantics`-подписью (FR-030);
`moodScore` — единственный источник значений списка/графика/CSV, тон реакций не подмешивается
(FR-011, SC-007); время — только через `AppClock`

**Scale/Scope**: один экран, ~40 функциональных требований, один новый экранный Cubit + одна
доменная сущность + один usecase + три новых метода чтения репозитория; страница списка — 30 дней,
история не ограничена

## Constitution Check

*GATE: пройден до Phase 0 и перепроверён после Phase 1 design.*

| Принцип | Как соблюдается | Статус |
|---|---|---|
| I. Слои, не фичи | `MoodChartPoint` — в плоском `domain/entities/`, `ExportDiaryToCsv` — в `domain/usecases/`, UI только в `presentation/diary/`; `DiaryCubit` зависит от абстрактного `DiaryRepository` и не импортирует ни `data/`, ни другие Cubit-ы и экраны (research.md R14) | PASS |
| II. Cubit и единый контракт состояний/ошибок | `DiaryState` — Freezed sealed `initial/loading/loaded/unavailable/error`; все новые методы репозитория возвращают `Result<T>` через `SafeCallMixin`; ошибка — подкласс `AppFailure`, текст берётся из `localizedMessage`; разовые сбои (экспорт, догрузка реплик) идут потоком `failures`, а не ломают экран (contracts/diary-cubit.md §3) | PASS |
| III. Офлайн-first ядро | Ни одного сетевого обращения на всём экране, включая экспорт (FR-025); график строится исключительно по `day_entries.moodScore`, тон/амплитуда реакций в него не попадают (FR-011, contracts/diary-repository.md §2) | PASS |
| IV. Детерминированное время | «День» записи вычисляется `DayResolver` внутри репозитория (research.md R15); `DateTime.now()` нигде — имя CSV-файла берёт время из `AppClock`; тесты на `FakeAppClock` | PASS |
| V. Секреты и приватность | Экран не отправляет ничего наружу; CSV формируется локально и уходит только в системный шаринг по явному действию пользователя — вне устройства данные оказываются лишь по его выбору | PASS |
| VI. Тестируемость и чистота | `bloc_test` на `DiaryCubit` — 16 сценариев (contracts/diary-cubit.md §4, >70%); моки — `mocktail`; отдельный a11y-тест на 48dp и подписи; `isFallback` кодируется иконкой, а не только цветом (FR-017); force unwrap только на `DayEntry.id` записей, пришедших из БД, — с явным обоснованием в `DiaryDay.entryId` | PASS |

**Cross-artifact analysis (2026-08-19, `/speckit-analyze`)**: сверка spec ↔ plan ↔ tasks нашла одно
критичное расхождение — `entriesPage` возвращал `List<DayEntry>`, у которого нет поля дня, тогда как
`DiaryDay` и колонка `date` в CSV его требуют. Контракт исправлен: метод возвращает `DiaryPage` с
`DiaryDayEntry`, `hasMore` и `nextCursor`; курсор перенесён на начало дня, дедупликация — по
`DayKey`. Заодно устранены зависимость фазы Foundational от usecase из US4 и три пробела покрытия
(FR-011/SC-007, SC-002, SC-008).

**Checklist review (2026-08-19, `checklists/diary.md`)**: проверка качества требований дала 42
пункта; 15 из них указали на реальные пробелы спеки. Все закрыты — четыре решением пользователя
(единое раскрытие карточки, начальный диапазон графика 30 дней, локальный формат даты без
«Сегодня/Вчера», отсутствие предупреждения о приватности при экспорте) и одиннадцать проектным
дефолтом (research.md R17–R19). Соответствующие правки внесены в `spec.md` (новая секция
Clarifications, исправленное допущение о `entriesBetween`, дополненные Edge Cases), `research.md`,
`data-model.md` и `contracts/*`. Состав принципов конституции решениями не затронут.

**Post-design re-check (после Phase 1)**: `data-model.md`, `contracts/*` и `quickstart.md` не вводят
ни одной сущности вне слоёв, ни одного прямого `DateTime.now()`, ни одной ветки, где отказ ломает
офлайн-ядро, и ни одного второго механизма там, где уже есть первый (`ShareService`, `MoodScale`,
`DayResolver` переиспользуются). Гейт пройден повторно, состав принципов не изменился.

## Project Structure

### Documentation (this feature)

```text
specs/005-diary-screen/
├── plan.md              # этот файл
├── research.md          # Phase 0 — 16 решений (R1..R16)
├── data-model.md        # Phase 1 — сущности, состояние экрана, новые константы
├── quickstart.md        # Phase 1 — как проверить, что фича работает
├── contracts/
│   ├── diary-repository.md   # три новых метода чтения + методы datasource
│   ├── diary-cubit.md        # публичный API экранного Cubit-а и его тесты
│   └── csv-export.md         # формат, экранирование, граничные случаи CSV
├── checklists/               # чек-листы качества спеки
└── tasks.md                  # Phase 2 — создаётся /speckit-tasks, не этой командой
```

### Source Code (repository root)

```text
app/
├── pubspec.yaml                              # MOD — fl_chart ^1.2.0 (R1)
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart            # MOD — 6 констант Дневника (data-model.md §5)
│   │   ├── sharing/
│   │   │   └── share_service.dart            # MOD — shareCsv поверх того же share_plus (R10)
│   │   └── di/
│   │       └── injection_module.dart         # MOD — DiaryCubit (@injectable), ExportDiaryToCsv
│   ├── data/
│   │   ├── datasources/
│   │   │   └── diary_local_datasource.dart   # MOD — entriesBefore, moodProjection, reactionsForEntryIds
│   │   ├── mappers/
│   │   │   └── day_entry_mapper.dart         # MOD — проекция строки → MoodChartPoint (R4)
│   │   └── repositories/
│   │       ├── diary_repository_impl.dart    # MOD — entriesPage, moodHistory, reactionsForEntries
│   │       └── read_only_repositories.dart   # MOD — те же три метода → storageReadOnly (R13)
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── mood_chart_point.dart         # NEW — день + moodScore (R4)
│   │   │   ├── diary_day_entry.dart          # NEW — день + запись (contracts/diary-repository.md §1)
│   │   │   └── diary_page.dart               # NEW — days + hasMore + nextCursor
│   │   ├── repositories/
│   │   │   └── diary_repository.dart         # MOD — три новых метода чтения
│   │   └── usecases/
│   │       └── export_diary_to_csv.dart      # NEW — формирование CSV (R9, R11)
│   ├── l10n/
│   │   ├── intl_ru.arb                       # MOD — строки Дневника (обязательный русский)
│   │   ├── intl_en.arb                       # MOD
│   │   └── intl_uk.arb                       # MOD
│   ├── app/router/
│   │   └── app_router.dart                   # MOD — DiaryPage вместо DiaryPlaceholderPage
│   └── presentation/diary/
│       ├── cubit/
│       │   ├── diary_cubit.dart              # NEW — contracts/diary-cubit.md
│       │   └── diary_state.dart              # NEW — Freezed sealed + DiaryData + DiaryDay
│       ├── diary_page.dart                   # NEW — заменяет diary_placeholder_page.dart
│       └── widgets/
│           ├── mood_chart.dart               # NEW — fl_chart + зум + агрегация (R5, R6)
│           ├── diary_day_card.dart           # NEW — дата, эмодзи, текст, раскрытие (FR-001, FR-014)
│           ├── diary_reactions_list.dart     # NEW — реплики дня (FR-015..FR-019)
│           ├── diary_empty_view.dart         # NEW — пустое состояние (FR-007)
│           └── diary_error_view.dart         # NEW — баннеры error / unavailable (FR-008a, FR-029)
└── test/
    ├── data/diary_repository_test.dart       # MOD — три новых метода
    ├── domain/export_diary_to_csv_test.dart  # NEW — формат и экранирование
    ├── presentation/diary_cubit_test.dart    # NEW — 16 сценариев
    ├── widget/diary_page_test.dart           # NEW
    └── widget/diary_accessibility_test.dart  # NEW
```

`presentation/diary/diary_placeholder_page.dart` удаляется вместе с переключением маршрута.

**Structure Decision**: сохраняется принятая в проекте слоистая раскладка (принцип I): `domain/` и
`data/` остаются плоскими на всё приложение, по экрану делится только `presentation/`, поэтому вся
новая UI-часть живёт в `presentation/diary/`, а всё переиспользуемое (сущность точки графика,
usecase экспорта, методы репозитория) — в общих `domain/`/`data/`. Feature-first-каталог для
Дневника не заводится.

## Complexity Tracking

> Заполнен не из-за нарушения конституции, а из-за одного осознанного отступления от **Assumptions**
> спеки. Требования спеки при этом не нарушены — наоборот, отступление сделано ради их выполнения.

| Отступление | Зачем нужно | Почему отвергнут вариант из Assumptions |
|---|---|---|
| Три новых метода чтения в `DiaryRepository` (`entriesPage`, `moodHistory`, `reactionsForEntries`) вместо обещанного «обойтись существующим `entriesBetween`» | FR-004c требует достоверного признака «дней больше нет», SC-001/SC-008 — предсказуемого времени страницы, FR-010 — графика по всей истории, SC-005 — экспорта без N+1 запросов | `entriesBetween(from, to)` не отвечает на вопрос «есть ли что-то старее» иначе как ещё одним диапазонным запросом: при разрыве в истории одна «страница» превращается в десятки пустых запросов, а размер страницы в календарных днях не равен размеру в записях. Плюс он тянет `dayText` там, где графику нужны два числа (research.md R2, R3, R11) |

Существующие методы и их семантика не меняются — фаза 004 и `ReminderCoordinator` не затронуты.
