---

description: "Task list for 006-table-surface-render"
---

# Tasks: Визуальная поверхность стола

**Input**: Design documents from `/specs/006-table-surface-render/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [quickstart.md](./quickstart.md)

**Tests**: включены — не по умолчанию шаблона, а по требованию конституции §VI (Тестируемость и
чистота кода) и плану тестов `research.md` R7. `bloc_test` не применим — фича не добавляет ни
Cubit, ни состояния.

**Organization**: у спеки одна user story (P1) — «Видеть стол под персонажами»; задачи
сгруппированы под неё одной фазой, как и предполагает единственный приоритет в `spec.md`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: можно выполнять параллельно (разные файлы, нет зависимостей от незавершённых задач)
- **[Story]**: к какой user story относится задача (US1)
- В описании — точный путь к файлу

## Path Conventions

Мобильное приложение, слоистая архитектура. Корень модуля — `app/`; исходники `app/lib/`, тесты
`app/test/`. Все пути ниже — от корня репозитория.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: константы, нужные и реализации, и тестам

- [ ] T001 Добавить 4 константы поверхности стола в `app/lib/core/constants/app_constants.dart`:
      `tableSurfaceFlattenRatio` (`0.78`), `tableSurfaceShadowOffsetY` (`6.0`),
      `tableSurfaceShadowBlurSigma` (`12.0`), `tableSurfaceShadowOpacity` (`0.35`)
      (data-model.md §4)

**Checkpoint**: константы на месте — можно начинать единственную user story

---

## Phase 2: User Story 1 — Видеть стол под персонажами (Priority: P1) 🎯 MVP

**Goal**: под персонажами на экране «Стол» отрисован приплюснутый овал с радиальным градиентом и
мягкой тенью — та же окружность, что уже использует раскладка персонажей, декоративен для
программ чтения с экрана, не перехватывает нажатия, не проседает по FPS.

**Independent Test**: открыть вкладку «Стол» с любым числом персонажей → под ними видна
эллиптическая поверхность с градиентом и тенью; изменение размера экрана, ориентации или темы не
ломает и не рассинхронизирует её с раскладкой персонажей.

### Tests for User Story 1 ⚠️

> Пишутся до реализации и должны падать до неё

- [ ] T002 [P] [US1] Написать юнит-тесты чистой функции `tableSurfaceRect(...)` в
      `app/test/presentation/table_surface_geometry_test.dart`: вертикальная полуось равна
      `radius`; горизонтальная — `radius / AppConstants.tableSurfaceFlattenRatio`, когда это не
      превышает `size.width / 2`; клэмп к `size.width / 2` на узком экране; результат
      симметричен относительно `center`; `radius <= 0` → `Rect.zero` (research.md R1, R7;
      data-model.md §1). В том же файле — юнит-тесты `TableSurfacePainter.shouldRepaint`:
      `false`, когда `center`/`radius`/`colorScheme` у старого и нового делегата совпадают
      (FR-010: стол не мигает при выборе настроения/вводе текста/получении реплики — ни одно из
      этих действий не меняет ни центр, ни радиус, ни тему); `true`, когда любое из трёх
      отличается (research.md R5)
- [ ] T003 [P] [US1] Написать widget-тест в `app/test/widget/table_surface_render_test.dart`:
      `RoundTableLayout` рисует `CustomPaint` с `TableSurfacePainter` без исключений при 1 и при
      `AppConstants.maxCharactersAtTable` персонажах; `ExcludeSemantics` присутствует и не
      добавляет объявляемых узлов — существующий набор гайдлайнов доступности экрана «Стол» не
      регрессирует (research.md R6, R7)

### Implementation for User Story 1

- [ ] T004 [US1] Создать `app/lib/presentation/table/widgets/table_surface_painter.dart`:
      чистая функция `tableSurfaceRect({required Offset center, required double radius,
      required Size bounds})` (research.md R1; должна удовлетворять T002) и класс
      `TableSurfacePainter extends CustomPainter` — тень: размытый овал того же `Path`, смещённый
      на `tableSurfaceShadowOffsetY`, `colorScheme.shadow` с прозрачностью
      `tableSurfaceShadowOpacity`, `Paint.maskFilter = MaskFilter.blur(BlurStyle.normal,
      tableSurfaceShadowBlurSigma)` (research.md R3); заливка — `RadialGradient(center:
      Alignment(-0.3, -0.35), radius: 0.95, colors: [colorScheme.surfaceContainerHighest,
      colorScheme.primaryContainer]).createShader(rect)` (research.md R4); `shouldRepaint`
      сравнивает `center`/`radius`/использованные цвета со старым делегатом (research.md R5)
      (зависит от T001)
- [ ] T005 [US1] Подключить `TableSurfacePainter` в
      `app/lib/presentation/table/widgets/round_table_layout.dart`: первым (нижним) элементом
      уже существующего `Stack` добавить `ExcludeSemantics(child: CustomPaint(painter:
      TableSurfacePainter(center: center, radius: radius, colorScheme:
      Theme.of(context).colorScheme)))`, используя `center`/`radius`, уже вычисленные в
      `build()` — без второго `LayoutBuilder` (research.md R2, R6; должно удовлетворять T003)
      (зависит от T004)

**Checkpoint**: US1 полностью работает и проверяется независимо — это единственная и вся фича

---

## Phase 3: Polish & Cross-Cutting Concerns

**Purpose**: гейты завершения задачи

- [ ] T006 [P] Прогнать `flutter analyze` в `app/` без ошибок и `flutter test` полностью зелёным
      (конституция §Рабочий процесс п.5 — задача с падающими тестами не считается выполненной)
- [ ] T007 Пройти сценарии A–E из `specs/006-table-surface-render/quickstart.md` на реальном
      среднем Android-устройстве: число персонажей (1 и максимум), ресайз/поворот, смена темы,
      взаимодействие и TalkBack/VoiceOver, частота кадров простаивающих анимаций (SC-001..SC-004,
      FR-009)
- [ ] T008 Дописать в `project/process/lessons-learned.md` реальные грабли этой фазы, если они
      были (только то, что действительно потребовало переписывания, — гипотетические уроки туда
      не пишутся)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: без зависимостей, стартует сразу
- **User Story 1 (Phase 2)**: после Setup — единственная история фичи, ничего не блокирует и
  ничем не заблокирована
- **Polish (Phase 3)**: после Phase 2

### Within User Story 1

- Тесты (T002, T003) пишутся до реализации и должны падать до неё
- Чистая функция и `CustomPainter` (T004) — до подключения в раскладку (T005), так как T005
  использует уже написанный `TableSurfacePainter`

### Parallel Opportunities

- T002 и T003 — разные файлы, можно писать вместе
- T001 не блокирует написание тестов (T002/T003 тестируют поведение, не читают константы
  напрямую), но блокирует реализацию (T004)

---

## Parallel Example: User Story 1

```bash
# Тесты US1 — два разных файла, запускаются вместе:
Task: "Юнит-тесты tableSurfaceRect в app/test/presentation/table_surface_geometry_test.dart"
Task: "Widget-тест отрисовки в app/test/widget/table_surface_render_test.dart"
```

---

## Implementation Strategy

### MVP First (единственная история)

1. Phase 1: Setup (T001)
2. Phase 2: User Story 1 (T002–T005)
3. **STOP и проверить**: сценарии A–E из `quickstart.md` — стол виден, переживает ресайз/смену
   темы, не мешает взаимодействию и доступности
4. Phase 3: Polish (T006–T008) — гейты завершения

### Incremental Delivery

Фича — один срез, инкрементальной поставки по историям нет (в спеке одна user story). После
Phase 2 фича уже полностью функциональна; Phase 3 закрывает гейты качества перед завершением
задачи.

---

## Notes

- Кодогенерация (`build_runner`) не нужна — фича не трогает `@freezed`/`@injectable`/Drift-таблицы.
- Новых пакетов в `pubspec.yaml` не добавляется — `CustomPainter`/`Canvas` уже часть Flutter SDK.
- `domain/`, `data/`, `TableCubit`/`TableState` не меняются — вся работа в
  `presentation/table/widgets/` и одна правка `core/constants/app_constants.dart`.
- `[P]` = разные файлы без зависимостей; коммит после каждой задачи или логической группы
