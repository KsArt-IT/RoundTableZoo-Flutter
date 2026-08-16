# Implementation Plan: Настройки — тема, язык, напоминания

**Branch**: `002-settings-and-reminders` | **Date**: 2026-08-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-settings-and-reminders/spec.md`

## Summary

Заменить заглушку `/settings` рабочим экраном (тема, язык, время напоминания, звук) и добавить
ежедневное напоминание с гарантией доставки на Android и iOS.

Хранилище настроек, значения по умолчанию и мгновенное применение темы/языка уже сделаны в
`001-app-foundation` — не хватает пути записи и UI. Напоминания строятся целиком с нуля.

Ключевое техническое решение — **скользящее окно одноразовых уведомлений** на 7 дней с
детерминированным `id` по дню (`YYYYMMDD`) вместо повторяющегося ежедневного уведомления.
Повторяющееся невозможно погасить на один день, а FR-014a требует именно этого: отметил
настроение — сегодняшнее напоминание исчезает, завтрашнее остаётся. Согласование очереди
идемпотентно и запускается на старте, на resume, при изменении настроек и при изменении
`day_entries`.

## Technical Context

**Language/Version**: Dart 3.13+ / Flutter (SDK `^3.13.0` в `app/pubspec.yaml`)

**Primary Dependencies**: `flutter_local_notifications ^22.3.0` (установлена 22.3.0),
`timezone ^0.11.1`, `flutter_timezone ^5.1.0`, `flutter_bloc`, `get_it` + `injectable`, `drift`,
`go_router`, `freezed`. Все уже объявлены — новых пакетов фича не добавляет.

**Storage**: Drift (локально). **Схема не меняется**: колонки `reminder_enabled` и `reminder_time`
в `user_settings` уже существуют, `schemaVersion` не поднимается.

**Testing**: `flutter_test`, `bloc_test`, `mocktail`, `FakeAppClock`. Доставка уведомлений,
перезагрузка и смена пояса — ручной прогон по [quickstart.md](./quickstart.md).

**Target Platform**: Android и iOS. Публикуется только Android, но по решению из
[Clarifications Q4](./spec.md) поведение напоминаний специфицировано и проверяется на обеих.

**Project Type**: Мобильное приложение, один модуль `app/`.

**Performance Goals**: смена темы/языка отражается без перезапуска и без промежуточного пустого
кадра (SC-002). `reconcile()` не блокирует UI: вызывается асинхронно, не в `build`.

**Constraints**: офлайн-first — фича сети не касается вовсе. Не больше
`AppConstants.reminderHorizonDays` (7) ожидающих уведомлений при платформенном минимуме 64
(FR-025c). Точность срабатывания — inexact, допуск не более 60 минут позже срока (FR-023);
разрешение `SCHEDULE_EXACT_ALARM` не запрашивается. Баннер показывается и на переднем плане
(FR-016d), что на iOS требует зарегистрированного `UNUserNotificationCenter.delegate`.

**Scale/Scope**: один экран, один экранный Cubit, один сервис в `core/`, один чистый domain-сервис,
+2 метода в `SettingsRepository`, +1 в `DiaryRepository`, правки Android-манифеста и iOS-делегата.

Открытых `NEEDS CLARIFICATION` нет — все разрешены в [research.md](./research.md).

## Constitution Check

*GATE: пройден до Phase 0 и повторно после Phase 1 — результат не изменился.*

| Принцип | Как соблюдается | Статус |
|---|---|---|
| **I. Слои, не фичи** | `ReminderPlanner` — чистый Dart в `domain/services/`, без Flutter и плагинов. `flutter_local_notifications` импортируется **только** в `core/notifications/`. `presentation/settings/` не знает ни про Drift, ни про FLN, ни про другие экраны. | PASS |
| **II. Cubit и единый контракт** | `SettingsCubit` — Cubit (не Bloc-события), состояния Freezed sealed. Новые методы репозиториев возвращают `Result<T>` через `SafeCallMixin`. Ошибки — подклассы `AppFailure`, тост через существующий `RootBlocListener`, текст только из `localizedMessage`. | PASS |
| **III. Офлайн-first** | Фича целиком локальная, сети не касается. | PASS |
| **IV. Детерминированное время** | `ReminderPlanner` принимает `nowUtc` параметром; `DateTime.now()` не вызывается нигде. `reconcile()` берёт время из `AppClock.nowUtc()` и зону из `AppClock.location`. Тесты — `FakeAppClock`. | PASS |
| **V. Секреты и приватность** | Ключей нет. `payload` уведомления — константа `'reminder'`, без даты и текста. Текст уведомления нейтрален и не раскрывает назначение приложения на заблокированном экране (FR-016a), что подкреплено тестом на стоп-слова. | PASS |
| **VI. Тестируемость и чистота** | `bloc_test` на `SettingsCubit` (цель >70%), unit-тесты на планировщик и координатор, моки — `mocktail`. Тап-таргеты `AppConstants.minTapTargetDp` и `Semantics(label:)` с текущим значением; выбранный вариант кодируется не только цветом. Force unwrap / небезопасный `as` / `late` без гарантии — не вводятся. | PASS |

**Технологические ограничения**: WorkManager не используется — `flutter_local_notifications` как
сервис в `core/notifications/`, как и предписано. Миграция БД не нужна: схема не меняется.

**Нарушений нет** — раздел Complexity Tracking пуст и удалён.

### Проверки, специфичные для этого проекта

- **DRY (CLAUDE.md)**: правило «неподдерживаемый язык → русский» переиспользуется из
  `core/utils/locale_resolution.dart`, а не пишется второй раз. Разрешения берутся из API самого
  FLN — обёртка над `permission_handler` не заводится (research.md, R4). Новых сущностей,
  дублирующих существующие, нет: `UserSettings`, `ReminderTime`, `DayKey`, `DayResolver`
  используются как есть.
- **lessons-learned.md**: фича **не вводит новых глобальных Cubit-ов**. `ReminderCoordinator` —
  обычный сервис, `SettingsCubit` — экранный factory. Тройка отказов widget-тестов из журнала
  граблей не воспроизводится. Любой новый widget-тест на `buildTestAppRoot()` обязан звать
  `disposeTestAppRoot(tester)` последней строкой.

## Project Structure

### Documentation (this feature)

```text
specs/002-settings-and-reminders/
├── plan.md              # Этот файл
├── spec.md              # Требования (+ 5 уточнений)
├── research.md          # Phase 0 — 12 решений
├── data-model.md        # Phase 1 — сущности, схема БД не меняется
├── quickstart.md        # Phase 1 — прогон проверок
├── contracts/
│   ├── notifications.md #   порт NotificationScheduler + ReminderCoordinator
│   ├── repositories.md  #   +2 метода SettingsRepository, +1 DiaryRepository
│   └── ui-contracts.md  #   SettingsCubit, SettingsPage, строки l10n
├── checklists/
│   └── requirements.md  # 16/16
└── tasks.md             # Phase 2 — создаётся /speckit-tasks, НЕ этой командой
```

### Source Code (repository root)

```text
app/
├── lib/
│   ├── domain/
│   │   ├── entities/
│   │   │   └── reminder_occurrence.dart        # НОВОЕ
│   │   ├── repositories/
│   │   │   ├── settings_repository.dart        # +updateReminderEnabled, +updateReminderTime
│   │   │   └── diary_repository.dart           # +watchEntriesChanged
│   │   └── services/
│   │       ├── day_resolver.dart               # без изменений, переиспользуется
│   │       └── reminder_planner.dart           # НОВОЕ — чистая функция планирования
│   ├── data/
│   │   ├── datasources/
│   │   │   └── diary_local_datasource.dart     # +наблюдение day_entries
│   │   └── repositories/
│   │       ├── settings_repository_impl.dart   # +2 сеттера через _update
│   │       ├── diary_repository_impl.dart      # +watchEntriesChanged
│   │       └── read_only_repositories.dart     # те же 3 метода в read-only-заглушках
│   ├── core/
│   │   ├── constants/                          # +reminderHorizonDays
│   │   ├── di/injection_module.dart            # +NotificationScheduler, +ReminderCoordinator
│   │   └── notifications/                      # НОВЫЙ пакет
│   │       ├── notification_scheduler.dart         #   порт
│   │       ├── flutter_local_notification_scheduler.dart  # реализация (единственный импорт FLN)
│   │       ├── notification_permission_status.dart
│   │       ├── notification_launch_queue.dart      #   тап при живом приложении
│   │       ├── reminder_texts.dart                 #   локализация без BuildContext
│   │       └── reminder_coordinator.dart           #   согласование очереди
│   ├── app/
│   │   ├── app_root.dart                       # resume: updateLocation → reconcile
│   │   ├── root_bloc_listener.dart             # +разовый тост об отсутствии разрешения (FR-021b)
│   │   └── router/app_router.dart              # /settings → SettingsPage
│   ├── presentation/settings/                  # заглушка заменяется
│   │   ├── cubit/settings_cubit.dart           # НОВОЕ
│   │   ├── cubit/settings_state.dart           # НОВОЕ
│   │   ├── settings_page.dart                  # НОВОЕ
│   │   └── widgets/                            # секции экрана
│   ├── l10n/intl_{ru,uk,en}.arb                # +строки экрана и уведомления
│   └── main.dart                               # init уведомлений, холодный старт по тапу
├── android/app/src/main/AndroidManifest.xml    # RECEIVE_BOOT_COMPLETED + 2 ресивера
├── ios/Runner/AppDelegate.swift                # UNUserNotificationCenter delegate (UIScene) — обязателен для FR-016d
└── test/
    ├── domain/services/reminder_planner_test.dart
    ├── core/notifications/reminder_coordinator_test.dart
    ├── core/notifications/reminder_texts_test.dart
    ├── presentation/settings/settings_cubit_test.dart
    └── widget/settings_page_test.dart
```

**Structure Decision**: используется существующая раскладка «слои, не фичи» (принцип I) — новых
верхнеуровневых директорий не появляется, кроме `core/notifications/`, которая прямо предписана
`project/architecture/architecture-full.md` и `build-order.md`. `presentation/settings/` — уже
существующая экранная папка, в ней заменяется содержимое.

## Порядок реализации

Следует `project/architecture/build-order.md` (снизу вверх: то, от чего зависят другие, — раньше).
Детальная разбивка — задача `/speckit-tasks`; здесь только слои и их зависимости.

| # | Слой | Содержание | Зависит от |
|---|---|---|---|
| 1 | `domain/` | `ReminderOccurrence`, `ReminderPlanner`, +3 метода в интерфейсах репозиториев | — |
| 2 | `data/` | Реализация трёх новых методов репозиториев — включая `read_only_repositories.dart` (иначе не скомпилируется) | 1 |
| 3 | `core/notifications/` | Порт, реализация на FLN, тексты, координатор | 1, 2 |
| 4 | Платформа | Android-манифест, iOS-делегат | 3 |
| 5 | `main.dart` / `AppRoot` | Инициализация, холодный старт по тапу, `reconcile` на resume, разовый тост об отсутствии разрешения (FR-021b) | 3, 4 |
| 6 | `presentation/settings/` | Cubit, экран, секции, строки l10n | 1–3 |
| 7 | Роутер | `/settings` → `SettingsPage` | 6 |
| 8 | Тесты | Всё из [quickstart.md](./quickstart.md) | 1–7 |

Слои 1–2 и 6 дают отдельно демонстрируемые срезы: после 6+7 работают US1 (тема), US2 (язык) и US5
(звук) даже до того, как уведомления начнут доставляться.

**Осознанное расхождение с `tasks.md`**: таблица выше упорядочена по слоям (снизу вверх, как
предписывает `build-order.md`), а `tasks.md` группирует работу по историям и потому выносит
каркас экрана и маршрут в фазу Foundational — раньше домена. Это не противоречие: `build-order.md`
регулирует порядок для компонентов, от которых зависят другие, а каркас `/settings` ни от чего из
слоёв 1–5 не зависит и нужен, чтобы US1 была демонстрируема в одиночку. Внутри историй порядок
слоёв соблюдается.

## Риски

| Риск | Проявление | Что делаем |
|---|---|---|
| Пропущенные правки Android-манифеста | FR-024 не работает **вообще**, при этом всё остальное выглядит исправным | Слой 4 обязателен до ручных прогонов; сценарий 6 quickstart явно указывает манифест как первое, что проверять |
| Горизонт в 7 дней | Пользователь не открывал приложение >7 дней — напоминания иссякли | Осознанная цена (research.md, R2); горизонт — константа |
| Пользователь отозвал разрешение в системе | Очередь есть, доставки нет | `reconcile()` при `permission != granted` чистит очередь; экран показывает предупреждение (FR-021) |
| Копирайт уведомления перепишут и он раскроет назначение | Нарушение FR-016a молча | Тест на стоп-слова во всех трёх языках, включая имя и описание канала (FR-016b, contracts/notifications.md) |
| Забыть делегат `UNUserNotificationCenter` на iOS | Баннер на переднем плане молча подавляется — FR-016d нарушен, но только на одной платформе и только в одном состоянии | Слой 4 обязателен; сценарий 11 quickstart проверяет передний план отдельно на обеих платформах |
| iOS-проверка требует реального устройства | Паритет платформ (Q4) не подтверждён | Явно вынесено в quickstart, сценарий 10 |
| Режим read-only хранилища | Настройки не сохраняются, напоминание включить нельзя | `ReadOnlySettingsRepository` возвращает `DatabaseFailure.storageReadOnly` и на новых сеттерах — экран показывает ту же понятную ошибку, что и на остальных (FR-003). `reminderEnabled` в этом режиме всегда `false`, значит координатор ничего не планирует — отдельной ветки не требуется |
