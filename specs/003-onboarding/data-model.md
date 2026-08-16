# Data Model: Онбординг — первый запуск

Фича **не вводит новых сущностей, таблиц и полей**. Ниже — то, что она читает и пишет, и
единственная новая структура: состояние Cubit-а (не персистентная).

## Персистентные данные

### `user_settings.has_seen_onboarding` (существует)

| Свойство | Значение |
|---|---|
| Таблица | `user_settings` (одна строка, `app/lib/data/datasources/drift/tables/app_tables.dart`) |
| Колонка | `BoolColumn has_seen_onboarding`, `withDefault(Constant(false))` |
| Entity | `UserSettings.hasSeenOnboarding` (`domain/entities/user_settings.dart`) |
| Чтение | `SettingsRepository.load()` — уже вызывается в `main.dart` |
| Запись | `SettingsRepository.markOnboardingSeen()` — метод существует, до этой фичи не вызывался ниоткуда |
| Изменения схемы | **нет**; `schemaVersion` не поднимается, миграция не пишется |

Переходы значения: `false` (создание строки на первом запуске) → `true` (единственная запись, при
подтверждении онбординга). Обратного перехода в этой фиче нет — сброс возможен только через
удаление данных (`AppBootstrap.resetData()`, фича 001).

В режиме `StorageMode.readOnly` источником служит `ReadOnlySettingsRepository`, который всегда
отдаёт `hasSeenOnboarding: false`, а `markOnboardingSeen()` возвращает
`DatabaseFailure(code: storageReadOnly)`. Это ожидаемо и покрыто FR-006b.

## Состояние в памяти

### `OnboardingState` (новый, Freezed sealed)

`app/lib/presentation/onboarding/cubit/onboarding_state.dart`

| Состояние | Смысл | Поведение редиректа | Кнопка |
|---|---|---|---|
| `unknown` | Репозиторий ещё недоступен, значение флага не запрашивалось | редирект на `/onboarding` **не** срабатывает | экран не показан |
| `required` | Флаг прочитан, равен `false` — онбординг нужно показать | любой маршрут → `/onboarding` | активна |
| `submitting` | Идёт запись `markOnboardingSeen()` | остаёмся на `/onboarding` | **недоступна** (FR-005a) |
| `completed` | Онбординг пройден в этой сессии (запись удалась или нет) | `/onboarding` → `/table`, иначе не вмешивается | экран покидается |

Полей у состояний нет: гейту не нужно ничего, кроме самой фазы (весь `UserSettings` читает
`AppSettingsCubit`, дублировать его здесь нельзя — DRY).

**Инварианты**

- `completed` терминально в пределах сессии: ни `resolve()`, ни повторный `complete()`, ни новое
  значение из хранилища не возвращают состояние назад (FR-006a, FR-007).
- `unknown` разрешается **только** через `resolve()`; из `required`/`submitting`/`completed`
  `resolve()` — no-op (R3).
- `resolve()` различает два отказа: репозиторий недоступен (локатор бросил) → остаёмся в `unknown`;
  репозиторий ответил `Result.failure` → `required`, потому что непрочитанный флаг трактуется как
  `false` (FR-001a). Молчаливый пропуск онбординга при сбое чтения недопустим.
- `complete()` в состояниях `submitting`/`completed` — no-op (FR-005a).
- Переходы: `unknown → required | completed` (resolve), `required → submitting` (complete),
  `submitting → completed` (запись завершилась любым исходом). Прочие переходы невозможны.

## Что фича сознательно не заводит

- Новой таблицы/сущности «онбординг» — флаг уже принадлежит `UserSettings`.
- Второго поля «показан в этой сессии» в БД — сессионность живёт только в памяти Cubit-а.
- Нового метода репозитория — `markOnboardingSeen()` достаточен.
- `error`-состояния — сбой записи не меняет ничего из того, что видит пользователь (research.md, R4).
