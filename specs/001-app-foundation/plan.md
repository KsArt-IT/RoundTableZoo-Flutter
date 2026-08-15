# Implementation Plan: Фундамент приложения (Фаза 0)

**Branch**: `001-app-foundation` | **Date**: 2026-08-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-app-foundation/spec.md`

## Summary

Фаза 0 заменяет демо-точку входа Flutter-шаблона на реальную оболочку продукта и закладывает три
несущих механизма, от которых зависят все следующие фазы:

1. **Оболочка и навигация** — `go_router` + `StatefulShellRoute.indexedStack` с тремя ветками
   («Стол», «Дневник», «Настройки»), заглушки страниц, зарегистрированный (но не блокирующий)
   маршрут онбординга и отдельный экран восстановления при недоступном хранилище.
2. **Локальное хранилище** — полная схема Drift из трёх таблиц (`day_entries`,
   `character_reactions`, `user_settings`), `schemaVersion = 1`, без `MigrationStrategy`;
   репозитории поверх `SafeCallMixin` возвращают `Result<T>`.
3. **Детерминированное время** — `AppClock` как единственный источник «сейчас», день записи
   вычисляется из хранимого UTC-момента по текущему поясу устройства с учётом «часа начала дня»
   (целое 0–23), с проверяемым ролловером через `FakeAppClock`.

Плюс сквозные механизмы: единый путь ошибок (`AppFailure` → `RootBlocListener` → тост с
подавлением дублей), мгновенное применение темы/языка через глобальный `AppSettingsCubit`,
режим «без сохранения» при недоступном хранилище и строго локальная диагностика.

Главная техническая развилка фазы: **день записи — вычисляемая величина, а не колонка**
(FR-009). Это снимает возможность переложить правило «одна запись на день» на уникальный индекс
БД — оно реализуется в транзакции репозитория. Расхождение с `project/architecture/
database-tables.md` (там `date` с уникальным индексом) зафиксировано ниже и требует правки того
документа.

## Technical Context

**Language/Version**: Dart SDK `^3.13.0`, Flutter (stable, канал совпадает с локальным SDK)

**Primary Dependencies**: `flutter_bloc`/`bloc` (Cubit — **заменяет `flutter_riverpod`, который
сейчас лежит в `pubspec.yaml` вопреки конституции**), `go_router` 17.x, `get_it` + `injectable`,
`drift` 2.x + `drift_flutter` + `sqlite3_flutter_libs`, `freezed` + `json_annotation`,
`timezone` + `flutter_timezone`, `toastification`, `logger`, `path_provider`, `intl` /
`flutter_localizations`

**Storage**: Drift (SQLite) на устройстве, файл БД в каталоге приложения; 3 таблицы,
`schemaVersion = 1`, миграций нет (см. конституцию: до первого релиза схема меняется поднятием
версии). Внешнего хранилища нет.

**Testing**: `flutter_test` + `bloc_test` + `mocktail`; Drift-тесты на `NativeDatabase.memory()`
(`sqlite3` dev-dep); время — `FakeAppClock` из `test/support/`; часовой пояс — реальные локации
пакета `timezone` (`Europe/Kyiv`, `Pacific/Kiritimati`, `America/Sao_Paulo` для DST)

**Target Platform**: Android (публикуется) + iOS (код кроссплатформенный, не публикуется);
minSdk — как в текущем `android/` шаблона

**Project Type**: Mobile app, single Flutter module (`app/`), слоистая архитектура

**Performance Goals**: холодный старт до интерактивной оболочки ≤ 2 с на среднем реальном
устройстве (SC-001); переключение вкладки ≤ 100 мс (SC-002); отсутствие потери состояния ветки
при переключении

**Constraints**: полностью офлайн (сеть в этой фазе не используется); ни одного `DateTime.now()`
в `domain/`/`data/`/Cubit; никакого внешнего сбора крашей и телеметрии; диагностика — только в
консоль отладочной сборки; данные не покидают устройство

**Scale/Scope**: ~1 запись дня в сутки на пользователя (порядок сотен строк за годы), 0..N реакций
на запись; 3 вкладки-заглушки + 1 экран восстановления; покрытие новой логики состояния ≥ 70%
(SC-009)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Принцип | Как соблюдается в этой фазе | Статус |
|---|---|---|
| I. Слои, не фичи | `domain/`/`data/` плоские; `presentation/` делится по экрану (`table`/`diary`/`settings`/`onboarding`/`storage_recovery`); оболочка и роутер — в `app/` | PASS |
| II. Cubit и единый контракт | Только Cubit; состояния Freezed sealed; репозитории возвращают `Result<T>` через `SafeCallMixin`; ошибки — подклассы `AppFailure`, поверхностны через `RootBlocListener` | PASS (требует замены Riverpod → `flutter_bloc` в `pubspec.yaml`) |
| III. Офлайн-first ядро | Фаза целиком офлайн; `moodScore` — обязательная явная колонка, не производная | PASS |
| IV. Детерминированное время | `AppClock` + `FakeAppClock`; `DayResolver` — чистая функция от (момент, пояс, `dayStartHour`); ролловер приходит тиком, время повторно не запрашивается | PASS |
| V. Секреты и приватность | Ключей и сети в фазе нет; `installId` — анонимный, не аккаунт; диагностика локальная и без пользовательского текста | PASS |
| VI. Тестируемость и чистота | `bloc_test` на каждый новый Cubit, `mocktail`, тап-таргет 48dp + `Semantics`, запрет `!`/небезопасного `as`/`late` без гарантии | PASS |

**Технологические ограничения**: Cubit ✓, Drift без миграций ✓, `get_it`+`injectable` ✓,
`go_router` ✓, Freezed ✓, локализация RU-минимум с готовой структурой `ru`/`uk`/`en` ✓,
WorkManager не используется ✓ (уведомления вообще вне этой фазы).

**Отклонения, требующие фиксации** (детали — в Complexity Tracking):

1. `pubspec.yaml` содержит Riverpod — прямое расхождение с принципом II, устраняется в этой фазе.
2. `project/architecture/database-tables.md` описывает `day_entries.date` с уникальным индексом —
   противоречит FR-009/FR-009a спеки. Спека старше (конституция: prd → architecture), документ
   архитектуры правится в рамках фазы.
3. Экран восстановления хранилища выходит за формулировку «разделы — только заглушки», но прямо
   требуется FR-021b.

**Post-Design re-check (после Phase 1)**: PASS — см. раздел «Constitution Re-Check» в конце.

## Project Structure

### Documentation (this feature)

```text
specs/001-app-foundation/
├── plan.md              # Этот файл
├── research.md          # Phase 0: решения и обоснования
├── data-model.md        # Phase 1: сущности, схема Drift, правила валидации
├── quickstart.md        # Phase 1: как запустить и чем проверить
├── contracts/
│   ├── repositories.md  # Контракты domain-репозиториев и их ошибок
│   ├── app-clock.md     # Контракт времени и вычисления дня
│   └── ui-contracts.md  # Маршруты, состояния Cubit, поверхность ошибок
├── checklists/
│   └── requirements.md  # Чек-лист качества спеки (уже есть)
└── tasks.md             # Phase 2 — создаёт /speckit-tasks, не этот шаг
```

### Source Code (repository root)

```text
app/
├── lib/
│   ├── main.dart                       # ЗАМЕНЯЕТСЯ: bootstrap → runApp(AppRoot)
│   ├── app/
│   │   ├── app_root.dart               # MultiBlocProvider + WidgetsBindingObserver (resume, tz)
│   │   ├── app_material_router.dart    # MaterialApp.router + themeMode/locale из AppSettingsCubit
│   │   ├── root_bloc_listener.dart     # тосты ошибок + подавление дублей
│   │   ├── router/
│   │   │   ├── app_router.dart         # go_router: StatefulShellRoute.indexedStack
│   │   │   └── app_routes.dart         # константы путей и имён
│   │   └── shell/
│   │       ├── shell_page.dart         # Scaffold + NavigationBar (3 раздела)
│   │       └── widgets/
│   │           └── read_only_banner.dart
│   ├── core/
│   │   ├── app_clock/
│   │   │   ├── app_clock.dart          # abstract interface
│   │   │   └── system_app_clock.dart   # прод-реализация (Timer.periodic)
│   │   ├── bootstrap/
│   │   │   ├── app_bootstrap.dart      # открытие БД + проба + StorageMode
│   │   │   └── storage_mode.dart
│   │   ├── constants/                  # СУЩЕСТВУЕТ: app_constants, app_dimens (+ mood_scale)
│   │   ├── di/                         # СУЩЕСТВУЕТ: injection, injection_module
│   │   ├── errors/                     # СУЩЕСТВУЕТ: app_failure, result, safe_call_mixin
│   │   │   └── failure_toast_gate.dart # НОВОЕ: правило подавления дублей (FR-021f)
│   │   ├── theme/                      # СУЩЕСТВУЕТ
│   │   ├── time_zone/                  # СУЩЕСТВУЕТ: инициализация tz
│   │   └── utils/                      # СУЩЕСТВУЕТ: app_logger (правится под FR-016c), time_guard
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── drift/
│   │   │   │   ├── app_database.dart
│   │   │   │   └── tables/
│   │   │   │       ├── diary_tables.dart   # day_entries, character_reactions
│   │   │   │       └── app_tables.dart     # user_settings
│   │   │   ├── diary_local_datasource.dart
│   │   │   └── settings_local_datasource.dart
│   │   ├── mappers/
│   │   │   ├── day_entry_mapper.dart
│   │   │   ├── character_reaction_mapper.dart
│   │   │   └── user_settings_mapper.dart
│   │   └── repositories/
│   │       ├── diary_repository_impl.dart
│   │       ├── settings_repository_impl.dart
│   │       └── read_only_repositories.dart  # реализации для режима без сохранения
│   ├── domain/
│   │   ├── entities/                   # DayEntry, CharacterReaction, UserSettings, DayKey
│   │   ├── repositories/               # DiaryRepository, SettingsRepository (abstract interface)
│   │   ├── services/
│   │   │   └── day_resolver.dart       # чистая логика «какой это день»
│   │   └── value_objects/              # MoodScore, DayStartHour, ReactionTone, ThemePreference…
│   ├── l10n/                           # СУЩЕСТВУЕТ: intl_ru/uk/en.arb (шаблон → ru)
│   └── presentation/
│       ├── table/                      # TablePlaceholderPage
│       ├── diary/                      # DiaryPlaceholderPage
│       ├── settings/                   # SettingsPlaceholderPage
│       ├── onboarding/                 # OnboardingPlaceholderPage (маршрут без редиректа)
│       ├── storage_recovery/           # StorageRecoveryPage + StorageRecoveryCubit
│       └── app_settings/               # AppSettingsCubit (глобальный: тема/язык/dayStartHour)
└── test/
    ├── support/
    │   ├── fake_app_clock.dart
    │   ├── test_database.dart          # NativeDatabase.memory + seed
    │   └── mocks.dart                  # mocktail-моки репозиториев
    ├── core/                           # day_resolver, failure_toast_gate, app_clock
    ├── data/                           # datasource + repository тесты на памяти
    ├── presentation/                   # bloc_test на каждый Cubit
    └── widget/                         # оболочка: навигация, тап-таргеты, семантика
```

**Structure Decision**: единый Flutter-модуль `app/` со слоистой раскладкой из
`project/architecture/architecture-brief.md`. `domain/` и `data/` плоские на всё приложение,
`presentation/` — по экрану. Новое относительно brief: `core/bootstrap/` (последовательность
запуска и режим хранилища), `domain/services/day_resolver.dart` и `domain/value_objects/` —
следствие того, что день стал вычисляемой величиной. `presentation/app_settings/` держит
глобальный `AppSettingsCubit`, который регистрируется в `AppRoot`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Экран `storage_recovery` сверх «только заглушки» | FR-021b/FR-021c/FR-021d требуют выбора пользователя при недоступном хранилище — без экрана требование неисполнимо | Диалог поверх оболочки отвергнут: оболочка сама зависит от настроек из БД, которых в этом состоянии нет |
| `DayResolver` + `DayKey` вместо колонки `date` | FR-009 запрещает хранить день как самостоятельное значение; пересчёт при смене пояса и «часа начала дня» иначе невозможен | Хранимая `date` с уникальным индексом дешевле, но прямо противоречит спеке и ломает FR-026 |
| Проверка «одна запись на день» в транзакции репозитория | Уникальный индекс невозможен по вычисляемому дню | Индекс по выражению в SQLite потребовал бы зашить `dayStartHour` и пояс в схему — при их смене индекс станет ложным |
| Отдельные `read_only_repositories.dart` | FR-021d требует работоспособной оболочки без хранилища | Флаг `isReadOnly` внутри обычных репозиториев размазал бы режим по всем методам и потребовал бы проверок на каждом вызове |
| Замена Riverpod на `flutter_bloc` в `pubspec.yaml` | Конституция, принцип II — Cubit не обсуждается | Оставить обе библиотеки — двойной стек состояния в фундаменте, худший вариант из возможных |

## Constitution Re-Check (после Phase 1)

- **I. Слои**: `domain/` в спроектированных контрактах не импортирует Flutter/Drift — `DayResolver`
  зависит только от `timezone` (чистый Dart-пакет). `presentation/` обращается только к
  абстрактным репозиториям. PASS
- **II. Cubit/Result**: все три новых Cubit (`AppSettingsCubit`, `CurrentDayCubit`,
  `StorageRecoveryCubit`) — Freezed sealed states, `Result<T>` на границе. PASS
- **III. Офлайн**: сети нет. PASS
- **IV. Время**: единственный `DateTime.now()` в кодовой базе — внутри `SystemAppClock`. PASS
- **V. Приватность**: `installId` генерируется локально `Random.secure()`, наружу не уходит;
  диагностика в релизе выключена. PASS
- **VI. Тестируемость**: каждый Cubit покрыт `bloc_test`, оболочка — widget-тестом на тап-таргеты
  и семантику. PASS

Новых нарушений дизайн не внёс; таблица Complexity Tracking остаётся полной и актуальной.
