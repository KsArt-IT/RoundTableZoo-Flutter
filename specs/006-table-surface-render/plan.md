# Implementation Plan: Визуальная поверхность стола

**Branch**: `006-table-surface-render` | **Date**: 2026-08-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-table-surface-render/spec.md`

## Summary

Добавить визуальную поверхность стола на экран «Стол» (фаза 004): приплюснутый овал с радиальным
градиентом и мягкой тенью, отрисованный `CustomPainter`-ом позади уже существующей раскладки
персонажей (`RoundTableLayout`). Чисто аддитивная, декоративная фича — ни раскладка персонажей, ни
`TableCubit`/`TableState`, ни что-либо в `domain/`/`data/` не меняются. Геометрия овала берёт тот же
центр и радиус, что `RoundTableLayout` уже вычисляет для окружности персонажей (без второго
`LayoutBuilder`), а цвета — из текущей `ColorScheme` темы приложения (без новых токенов дизайна).

## Technical Context

**Language/Version**: Dart 3.13+ / Flutter (SDK-ограничение `^3.13.0` из `app/pubspec.yaml`)

**Primary Dependencies**: только существующие — `flutter` (`CustomPainter`/`Canvas`, часть SDK, без
новых пакетов в `pubspec.yaml`)

**Storage**: не затрагивается — N/A (фича не читает и не пишет `day_entries`/что-либо ещё)

**Testing**: `flutter_test` — юнит-тесты чистой функции геометрии, widget-тест на отрисовку и
отсутствие регрессий доступности (research.md R7); `bloc_test` не применим — новых Cubit/состояний
нет

**Target Platform**: Android (публикуется) + iOS (собирается) — тот же экран «Стол», без новых
платформенных API

**Project Type**: мобильное приложение, слоистая архитектура (`presentation/` — единственный
затронутый слой)

**Performance Goals**: без заметной просадки FPS простаивающих анимаций персонажей на среднем
устройстве, тот же порог, что уже действует для экрана «Стол» (FR-009, SC-003, конституция
§Технологические ограничения)

**Constraints**: декоративность для программ чтения с экрана (FR-008); не перехватывает нажатия
(FR-007); цвета только из текущей `ColorScheme` темы, без новых констант дизайна вне
`AppConstants` (FR-006)

**Scale/Scope**: один новый файл-виджет (`table_surface_painter.dart`), правка одного существующего
виджета (`round_table_layout.dart`), 4 новые константы; ни новых экранов, ни новых Cubit/состояний,
ни новых зависимостей в `pubspec.yaml`

## Constitution Check

*GATE: пройден до Phase 0 и перепроверён после Phase 1 design.*

| Принцип | Как соблюдается | Статус |
|---|---|---|
| I. Слои, не фичи | Всё изменение — внутри `presentation/table/widgets/`; `TableSurfacePainter` не импортирует `data/` и не создаёт зависимости от других экранов (принцип I) | PASS |
| II. Cubit и единый контракт состояний/ошибок | Не применяется — фича не добавляет ни Cubit, ни состояние, ни путь ошибок; `TableState`/`TableCubit` не меняются | N/A |
| III. Офлайн-first ядро | Не применяется — фича не читает и не пишет данные, работает полностью локально по построению (чистая отрисовка) | N/A |
| IV. Детерминированное время | Не применяется — фича не использует время ни в каком виде | N/A |
| V. Секреты и приватность | Не применяется — фича не передаёт и не хранит никаких данных | N/A |
| VI. Тестируемость и чистота кода | Чистая функция геометрии покрыта юнит-тестами отдельно от виджета (research.md R7); `CustomPainter` без побочных эффектов и без `!`/небезопасных `as`; код-ревью по `project/process/code-quality.md` | PASS |

**Post-design re-check (после Phase 1)**: `data-model.md` и `quickstart.md` не вводят ни одной
сущности вне `presentation/`, ни одного нового пакета в `pubspec.yaml`, ни одного механизма,
дублирующего уже существующий (геометрия центра/радиуса переиспользуется из `RoundTableLayout`, а
не пересчитывается заново — research.md R2). Гейт пройден повторно, состав принципов не изменился.

## Project Structure

### Documentation (this feature)

```text
specs/006-table-surface-render/
├── plan.md              # этот файл
├── research.md          # Phase 0 — 7 решений (R1..R7)
├── data-model.md         # Phase 1 — геометрия, CustomPainter, новые константы
├── quickstart.md         # Phase 1 — как проверить фичу на устройстве
└── tasks.md              # Phase 2 — создаётся /speckit-tasks, не этой командой
```

Контракты (`contracts/`) не заводятся: фича не добавляет ни публичного репозитория, ни Cubit, ни
usecase — единственный новый публичный API — конструктор `TableSurfacePainter` и сигнатура
`tableSurfaceRect(...)`, оба уже полностью описаны в `data-model.md` §1–2.

### Source Code (repository root)

```text
app/
├── lib/
│   ├── core/
│   │   └── constants/
│   │       └── app_constants.dart                    # MOD — 4 константы поверхности стола (data-model.md §4)
│   └── presentation/table/
│       └── widgets/
│           ├── round_table_layout.dart               # MOD — нижний слой Stack: CustomPaint с TableSurfacePainter (research.md R1, R2)
│           └── table_surface_painter.dart             # NEW — tableSurfaceRect(...) + TableSurfacePainter (research.md R1, R3, R4, R5)
└── test/
    ├── presentation/
    │   └── table_surface_geometry_test.dart            # NEW — юнит-тесты tableSurfaceRect (research.md R7)
    └── widget/
        └── table_surface_render_test.dart               # NEW — CustomPaint рисуется, доступность не регрессирует (research.md R7)
```

**Structure Decision**: сохраняется принятая в проекте слоистая раскладка (принцип I) — весь новый
код живёт в `presentation/table/widgets/`, единственная общая правка (`app_constants.dart`) — в
`core/`, как и у всех предыдущих фаз. `domain/`, `data/`, `TableCubit`/`TableState` не трогаются;
`presentation/diary/` и другие экраны не затрагиваются (Out of Scope спеки).

## Complexity Tracking

*Раздел не заполнен — отступлений от Constitution Check нет.*
