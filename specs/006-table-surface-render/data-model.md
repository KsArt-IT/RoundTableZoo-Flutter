# Phase 1 — Data Model: Визуальная поверхность стола

**Feature**: `006-table-surface-render` | **Date**: 2026-08-20

Чисто визуальная фича — новых доменных сущностей, таблиц БД или полей состояния нет (FR-027 фазы
004 остаётся в силе: экран «Стол» не приобретает новых данных). Ниже — только модели уровня
реализации в `presentation/`.

---

## 1. Геометрия овала — чистая функция

`presentation/table/widgets/table_surface_painter.dart`:

```dart
/// Эллиптическая область стола, построенная вокруг той же окружности, на
/// которой `RoundTableLayout` уже расставляет персонажей (research.md R1).
/// Вертикальная полуось равна [radius] — верхнее/нижнее сиденье касается
/// края овала, а не выходит за него (FR-005). Горизонтальная полуось шире
/// [radius] (FR-003: приплюснутый овал), но не может превысить половину
/// ширины доступной области (клэмп — Edge Cases: «не вылезает за пределы»).
Rect tableSurfaceRect({required Offset center, required double radius, required Size bounds});
```

- Не принимает `BuildContext`/тему — чистая геометрия, тестируется без виджетного дерева
  (research.md R7).
- `radius <= 0` (вырожденный случай пустого `seats`) → возвращает `Rect.zero`; вызывающий
  (`RoundTableLayout`) не рисует поверхность стола, если персонажей нет — так же, как
  `_TableContent` уже не строит `RoundTableLayout` вовсе при `data.characters.isEmpty`
  (`table_page.dart`).

## 2. `TableSurfacePainter` — `CustomPainter`

`presentation/table/widgets/table_surface_painter.dart`:

```dart
class TableSurfacePainter extends CustomPainter {
  const TableSurfacePainter({
    required this.center,
    required this.radius,
    required this.colorScheme,
  });

  final Offset center;
  final double radius;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) { ... } // R3 (тень) + R4 (градиент)

  @override
  bool shouldRepaint(covariant TableSurfacePainter oldDelegate) => ...; // R5
}
```

- Единственный потребитель — `RoundTableLayout` (R2): передаёт `center`/`radius`, уже вычисленные в
  своём `LayoutBuilder`, и `Theme.of(context).colorScheme`.
- `paint()` использует `tableSurfaceRect` (§1) для построения `Path` заливки и тени; не хранит
  собственного состояния между кадрами.
- Оборачивается вызывающим в `ExcludeSemantics` (research.md R6) — сам `CustomPainter` семантики не
  строит и не обязан об этом знать.

## 3. Изменения в существующих файлах

| Файл | Что меняется |
|---|---|
| `presentation/table/widgets/round_table_layout.dart` (MOD) | Первым (нижним) элементом своего `Stack` рендерит `ExcludeSemantics(child: CustomPaint(painter: TableSurfacePainter(...)))`, используя уже вычисленные в `build()` `center`/`radius` (research.md R1, R2). Раскладка аватаров/баблов не меняется. |
| `core/constants/app_constants.dart` (MOD) | 4 новые константы — см. §4. |

Ни `table_page.dart`, ни `TableCubit`/`TableState`, ни что-либо в `domain/`/`data/` не меняются
(Out of Scope спеки: раскладка и бизнес-логика персонажей не трогаются).

## 4. Новые константы — `core/constants/app_constants.dart` (MOD)

| Константа | Значение | Требование |
|---|---|---|
| `tableSurfaceFlattenRatio` | `0.78` | FR-003, research.md R1 |
| `tableSurfaceShadowOffsetY` | `6.0` | FR-002, research.md R3 |
| `tableSurfaceShadowBlurSigma` | `12.0` | FR-002, research.md R3 |
| `tableSurfaceShadowOpacity` | `0.35` | FR-002, research.md R3 |
