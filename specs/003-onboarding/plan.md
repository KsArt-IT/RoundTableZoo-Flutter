# Implementation Plan: Онбординг — первый запуск

**Branch**: `003-onboarding` | **Date**: 2026-08-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/003-onboarding/spec.md`

## Summary

Заменить заглушку `/onboarding` рабочим экраном приветствия и включить гейт первого запуска:
пока `hasSeenOnboarding = false`, роутер ведёт пользователя на онбординг вместо стола.

Хранилище (`user_settings.hasSeenOnboarding`), путь записи (`SettingsRepository.markOnboardingSeen()`),
маршрут `/onboarding` и `OnboardingPlaceholderPage` уже существуют с `001-app-foundation` —
не хватает самого гейта, содержимого экрана и текстов.

Ключевое техническое решение — **гейт через `redirect` в go_router, а не подмена виджета**, по той
же схеме, что уже работает для storage-recovery: состояние держит app-scoped `OnboardingCubit`,
`refreshListenable` — `Listenable.merge` из двух `CubitRefreshListenable`. Второе решение —
**начальное состояние гейта вычисляется в `main.dart`** из уже загруженных там настроек, поэтому на
основном пути нет ни кадра со столом до редиректа. Флаг «пройдено» терминален в пределах сессии
(FR-006a), что закрывает и режим read-only, где запись невозможна в принципе (FR-006b).

## Technical Context

**Language/Version**: Dart 3.13+ / Flutter (SDK `^3.13.0` в `app/pubspec.yaml`)

**Primary Dependencies**: `flutter_bloc`, `go_router`, `get_it` + `injectable`, `freezed`, `drift`
(через существующий репозиторий). **Новых пакетов фича не добавляет.**

**Storage**: Drift (локально). **Схема не меняется**: колонка `has_seen_onboarding` уже есть в
`user_settings` (`app_tables.dart`, default `false`), `schemaVersion` не поднимается, миграция не
пишется (до релиза не требуется).

**Testing**: `flutter_test`, `bloc_test`, `mocktail`. Тест на прерывание процесса (US3) —
ручной прогон по [quickstart.md](./quickstart.md); всё остальное автоматизируется.

**Target Platform**: Android и iOS (публикуется только Android). Фича платформенного кода не
касается вовсе.

**Project Type**: Мобильное приложение, один модуль `app/`.

**Performance Goals**: на первом запуске экран онбординга — первый отрисованный экран после
`runApp`; кадр со столом до редиректа не показывается (FR-002, research.md R2).

**Constraints**: офлайн-first — фича сети не касается. Запись одного булева поля локальна, поэтому
ожидание её результата перед навигацией укладывается в незаметное пользователю время (FR-005) и не
требует видимого индикатора загрузки (FR-005a).

**Scale/Scope**: один экран, один app-scoped Cubit, +2 ветки в `redirect` роутера, 5 ключей l10n
×3 языка. Новых сущностей, таблиц, репозиториев и методов репозитория — ноль.

Открытых `NEEDS CLARIFICATION` нет: четыре неоднозначности разрешены в
[Clarifications](./spec.md#clarifications), технические — в [research.md](./research.md).

## Constitution Check

*GATE: пройден до Phase 0 и повторно после Phase 1 — результат не изменился.*

| Принцип | Как соблюдается | Статус |
|---|---|---|
| **I. Слои, не фичи** | Фича живёт целиком в `presentation/onboarding/` + две правки в `app/` (роутер, `AppRoot`). `domain/` и `data/` не меняются вообще. `presentation/onboarding/` не импортирует ни `data/`, ни другие экраны; координация с `StorageRecoveryCubit` — через `RootBlocListener`, не импортом Cubit-а в Cubit. | PASS |
| **II. Cubit и единый контракт** | `OnboardingCubit` — Cubit, состояния Freezed sealed. `markOnboardingSeen()` уже возвращает `Result<UserSettings>`; исключения в presentation не летят. Отдельного `error`-состояния нет намеренно — по FR-006 сбой записи не меняет то, что видит пользователь (research.md, R4). | PASS |
| **III. Офлайн-first** | Фича полностью локальная, сети не касается. Сбой хранилища не блокирует вход в приложение (FR-006). | PASS |
| **IV. Детерминированное время (AppClock)** | Календарного времени в фиче нет: `DateTime.now()` не вызывается, `AppClock` не требуется. Единственная временна́я величина — относительный таймаут ожидания записи (FR-005b), который к «какой сегодня день» отношения не имеет; он задаётся параметром конструктора, чтобы тест не ждал реальные три секунды. | PASS |
| **V. Секреты и приватность** | Ключей нет. Фича, наоборот, **закрывает** требование конституции «передача текста стороннему AI-сервису MUST быть явно раскрыта в первом запуске» — FR-004(c) и есть это раскрытие; оно проверяется тестом на присутствие пункта на экране. | PASS |
| **VI. Тестируемость и чистота** | `bloc_test` на `OnboardingCubit` (цель >70%): успех записи, сбой записи, таймаут записи, сбой чтения флага, повторный вызов при уже идущей записи, `isClosed` после `await`. Моки — `mocktail`. Тап-таргет кнопки ≥ `AppConstants.minTapTargetDp`, метки для screen reader, проверка при увеличенном шрифте — a11y-виджет-тест (FR-010, SC-004). Force unwrap / небезопасный `as` / `late` без гарантии не вводятся. | PASS |

**Технологические ограничения**: Cubit, `go_router`, Freezed, `get_it`/`injectable` — как
предписано. Схема БД не меняется, миграция не нужна.

**Нарушений нет** — раздел Complexity Tracking не заполняется.

### Проверки, специфичные для этого проекта

- **DRY (CLAUDE.md)**: новых сущностей не заводим. Флаг — существующее поле `UserSettings`;
  метод записи — существующий `markOnboardingSeen()` (сейчас не вызывается ниоткуда); маршрут и
  константы — существующие `AppRoutes.onboardingPath/Name`; механика редиректа и
  `CubitRefreshListenable` переиспользуются из storage-recovery, а не пишутся заново. Второй
  «источник истины» о факте показа не создаётся: `OnboardingCubit` — единственный, репозиторий
  остаётся хранилищем.
- **lessons-learned.md — обязательная сверка**: фича **вводит новый app-scoped Cubit, который
  реально читается** (в `redirect` роутера). Это ровно тот случай, который в журнале описан как
  повторяющийся: `test/support/test_app_root.dart` должен пересоздавать `OnboardingCubit` на
  каждый `buildTestAppRoot()`, а сам хелпер — по умолчанию считать онбординг пройденным, иначе
  **все существующие widget-тесты уедут на `/onboarding`** (свежая in-memory БД → `hasSeenOnboarding
  = false`). Детали и точная сигнатура — research.md, R7. Это самый вероятный источник поломки в
  этой фиче, и он ожидаем, а не гипотетичен.
- **Семантика (lessons-learned.md)**: на экране нет `ListTile`-подобных виджетов, поэтому граблей с
  merge boundary не возникает; кнопка продолжения — обычный `FilledButton` с текстовой меткой,
  собственный `Semantics` поверх неё не заводится.

## Project Structure

### Documentation (this feature)

```text
specs/003-onboarding/
├── plan.md              # Этот файл
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── ui-contracts.md  # Phase 1 — контракт экрана, гейта и Cubit-а
├── checklists/
│   └── requirements.md
├── spec.md
└── tasks.md             # Phase 2 (/speckit-tasks — этим планом не создаётся)
```

### Source Code (repository root)

```text
app/lib/
├── app/
│   ├── app_root.dart                      # изменяется: принимает и провайдит OnboardingCubit
│   ├── root_bloc_listener.dart            # изменяется: resolve() гейта при появлении хранилища
│   └── router/
│       └── app_router.dart                # изменяется: ветка редиректа на /onboarding
├── main.dart                              # изменяется: начальное состояние гейта из settings
├── l10n/
│   ├── intl_ru.arb                        # изменяется (template): ключи онбординга
│   ├── intl_en.arb                        # изменяется
│   └── intl_uk.arb                        # изменяется
└── presentation/onboarding/
    ├── onboarding_page.dart               # НОВЫЙ: заменяет onboarding_placeholder_page.dart
    ├── cubit/
    │   ├── onboarding_cubit.dart          # НОВЫЙ
    │   ├── onboarding_state.dart          # НОВЫЙ (Freezed sealed)
    │   └── onboarding_state.freezed.dart  # генерируется build_runner
    └── widgets/
        └── onboarding_points.dart         # НОВЫЙ: три пункта FR-004 (a)/(b)/(c)

app/lib/core/di/injection_module.dart      # изменяется: фабрика OnboardingCubit

app/test/
├── presentation/
│   └── onboarding_cubit_test.dart         # НОВЫЙ: bloc_test
├── widget/
│   ├── onboarding_gate_test.dart          # НОВЫЙ: редирект, back-стек, read-only
│   ├── onboarding_accessibility_test.dart # НОВЫЙ: FR-010 / SC-004
│   └── (существующие)                     # правок не требуют — см. research.md R7
└── support/test_app_root.dart             # изменяется: onboardingSeen, пересоздание Cubit-а
```

**Structure Decision**: слои, как в конституции — весь новый код в `presentation/onboarding/`,
`domain/` и `data/` не затрагиваются вообще. Изменения в `app/` — только точки подключения гейта
(роутер, корневой виджет, координация через `RootBlocListener`), по образцу уже работающего
storage-recovery.
