# Implementation Plan: Экран «Стол»

**Branch**: `004-table-screen` | **Date**: 2026-08-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-table-screen/spec.md`

## Summary

Заменить заглушку `/table` полноценным главным экраном: обязательная шкала настроения из пяти
эмодзи с записью в `day_entries` (работает офлайн), необязательный текст дня с автосохранением,
круглый стол из включённых персонажей и AI-реакции по тапу через backend-прокси.

Технически это первая фаза, которой нужна сеть: добавляются `dio`-клиент к ai-proxy
(`core/network/`), `AiReactionRepository`, каталог персонажей из ассета и экранный `TableCubit` с
generation-счётчиком на персонажа. Схема БД не меняется — все нужные таблицы и методы репозиториев
созданы фазами 001–003. Сам прокси в этот срез не входит: клиент разрабатывается против контракта
`backend-proxy.md` §4 и проверяется на заглушке, подтверждение подлинности (Play Integrity)
отложено до фазы прокси.

## Technical Context

**Language/Version**: Dart 3.13+ / Flutter (SDK-ограничение `^3.13.0` из `app/pubspec.yaml`)

**Primary Dependencies**: существующие — `flutter_bloc`, `freezed`, `injectable`+`get_it`,
`go_router`, `drift`, `lottie`, `json_serializable`; **новые** — `dio` (клиент ai-proxy, research.md
R1), `share_plus` (шаринг реплики, R3)

**Storage**: Drift, существующие таблицы `day_entries` / `character_reactions` / `user_settings`;
новых таблиц и миграций нет

**Testing**: `flutter_test`, `bloc_test`, `mocktail`, `fake_async`; widget-тесты через
`test/support/test_app_root.dart`

**Target Platform**: Android (публикуется) + iOS (собирается); экран не использует
платформо-специфичных API кроме системного шаринга

**Project Type**: мобильное приложение, слоистая архитектура (`domain`/`data`/`presentation`)

**Performance Goals**: 4–6 персонажей с idle-анимациями без заметных рывков на среднем устройстве
(SC-006); индикация ожидания ≤2 с, содержимое бабла ≤15 с (SC-007)

**Constraints**: отметка настроения и текст работают офлайн (SC-002); клиентский таймаут запроса
15 с; тап-таргеты ≥48dp; текст дня ≤2000 символов (`AppConstants.maxDayTextLength`); ключ Gemini и
промпты в клиенте отсутствуют

**Scale/Scope**: один экран, ~46 функциональных требований, 4 персонажа в MVP (структура держит до
6), один новый экранный Cubit + один новый репозиторий + один сетевой клиент

## Constitution Check

*GATE: пройден до Phase 0 и перепроверен после Phase 1 design.*

| Принцип | Как соблюдается | Статус |
|---|---|---|
| I. Слои, не фичи | `domain/entities/character.dart` и `domain/repositories/ai_reaction_repository.dart` — плоские; UI только в `presentation/table/`; `TableCubit` не импортирует другие Cubit-ы, координация с `CurrentDayCubit` — через `BlocListener` в `TablePage` (R5, R13) | PASS |
| II. Cubit и единый контракт ошибок | `TableState` — Freezed sealed `initial/loading/loaded/error`; репозитории возвращают `Result<T>` через `SafeCallMixin`; ошибки — подклассы `AppFailure`; `AiProxyFailure` конкретного персонажа даёт fallback-реплику, а не тост (data-model.md §3) | PASS |
| III. Офлайн-first ядро | Отметка и текст пишутся локально и не зависят от сети; `moodScore` задаётся явно и не выводится из тона реплик; все пять отказов AI имеют заданное поведение (contracts/ai-proxy-client.md §4) | PASS |
| IV. Детерминированное время | `TableCubit` получает `AppClock`; текущий день приходит из `CurrentDayCubit`, а не вычисляется заново; тесты на `FakeAppClock` + `fake_async` | PASS |
| V. Секреты и приватность | Промпты и ключ — на прокси; клиент шлёт только `installId`/`characterId`/`dayText`; `moodScore` и дневник устройство не покидают; раскрытие факта отправки текста внешнему AI — FR-034 | PASS с отложенным пунктом (см. ниже) |
| VI. Тестируемость и чистота | `bloc_test` на `TableCubit` (contracts/table-cubit.md §4, >70%), моки — `mocktail`, a11y-тест на гайдлайны, состояние «уже отвечал» кодируется иконкой, а не цветом | PASS |

**Отложенный пункт принципа V (не нарушение, а зафиксированная последовательность работ):**
Play Integrity — «обязательна, не опция» для прокси. В этом срезе прокси не существует, проверять
токен некому, поэтому запрос уходит без него (Clarifications Q1, spec «Out of Scope»). Релиз без
этой защиты невозможен; она закрывается фазой прокси вместе с rate limiting и kill switch.
`Complexity Tracking` не заполняется — обхода принципа нет, есть порядок фаз.

**Post-design re-check (после Phase 1):** артефакты `data-model.md`, `contracts/*`, `quickstart.md`
не вводят ни одной сущности вне слоёв, ни одного прямого `DateTime.now()`, ни одного секрета в
клиенте и ни одной ветки, где отказ AI ломает офлайн-ядро. Гейт пройден повторно, состав принципов
не изменился.

## Project Structure

### Documentation (this feature)

```text
specs/004-table-screen/
├── plan.md              # этот файл
├── research.md          # Phase 0 — 16 решений (R1..R16)
├── data-model.md        # Phase 1 — сущности и состояние экрана
├── quickstart.md        # Phase 1 — как проверить, что фича работает
├── contracts/
│   ├── ai-proxy-client.md    # запрос/ответ/таксономия отказов + заглушка
│   ├── character-config.md   # схема ассета персонажей
│   └── table-cubit.md        # публичный API экранного Cubit-а
├── checklists/
│   └── requirements.md  # чек-лист качества спеки (16/16)
└── tasks.md             # Phase 2 — создаётся /speckit-tasks, не этой командой
```

### Source Code (repository root)

```text
app/
├── assets/
│   ├── characters/
│   │   └── characters.json          # NEW — ростер MVP (contracts/character-config.md)
│   └── lottie/                      # idle/talk по мере появления ассетов
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart   # MOD — aiRequestTimeout, dayTextAutosaveDebounce
│   │   │   └── mood_scale.dart      # NEW — moodScore → эмодзи/цвет/ключ подписи (R15)
│   │   ├── errors/
│   │   │   └── app_failure.dart     # MOD — AiProxyFailure + localizedMessage (R7)
│   │   ├── network/
│   │   │   ├── ai_proxy_config.dart # NEW — PROXY_BASE_URL из --dart-define (R2)
│   │   │   ├── ai_proxy_client.dart # NEW — интерфейс + DioAiProxyClient (R1)
│   │   │   └── stub_ai_proxy_client.dart # NEW — заглушка до появления прокси (R14)
│   │   ├── sharing/
│   │   │   └── share_service.dart   # NEW — обёртка share_plus (R3)
│   │   └── di/
│   │       ├── injection_module.dart # MOD — TableCubit, AiProxyClient, каталог
│   │       └── storage_di_switch.dart # MOD — публикация StorageMode в DI (FR-032)
│   ├── data/
│   │   ├── datasources/
│   │   │   └── character_catalog.dart # NEW — загрузка/кэш ассета персонажей (R4)
│   │   ├── models/
│   │   │   └── ai_reaction_dto.dart   # NEW — @JsonSerializable ответ прокси
│   │   └── repositories/
│   │       └── ai_reaction_repository_impl.dart # NEW — единственный маппинг HTTP → AppFailure
│   ├── domain/
│   │   ├── entities/character.dart              # NEW
│   │   └── repositories/ai_reaction_repository.dart # NEW
│   └── presentation/table/
│       ├── table_page.dart          # NEW — заменяет table_placeholder_page.dart
│       ├── cubit/
│       │   ├── table_cubit.dart     # NEW
│       │   └── table_state.dart     # NEW (Freezed)
│       └── widgets/
│           ├── mood_scale_row.dart      # NEW — шкала эмодзи
│           ├── day_text_field.dart      # NEW — поле с лимитом и счётчиком
│           ├── round_table_layout.dart  # NEW — Stack + тригонометрия (R9)
│           ├── character_avatar.dart    # NEW — 4 состояния, Lottie/статика
│           └── speaking_bubble.dart     # NEW — эффект проговаривания + «поделиться» (R8)
└── test/
    ├── support/
    │   ├── mocks.dart               # MOD — моки AiReactionRepository, ShareService
    │   └── test_app_root.dart       # MOD — пересоздание CurrentDayCubit, подмена ShareService (R13)
    ├── data/
    │   ├── ai_reaction_repository_test.dart  # NEW — таксономия отказов
    │   └── character_catalog_test.dart       # NEW — разбор ассета
    ├── presentation/
    │   └── table_cubit_test.dart    # NEW — основное покрытие (contracts/table-cubit.md §4)
    └── widget/
        ├── table_page_test.dart          # NEW — сценарии US1–US3, US5
        └── table_accessibility_test.dart # NEW — гайдлайны, метки состояний
```

**Structure Decision**: сохраняется принятая в проекте слоистая раскладка. `domain/` и `data/`
остаются плоскими: `Character` и `AiReactionRepository` кладутся рядом с существующими сущностями и
репозиториями, а не в папку «фичи стола», хотя пока их использует один экран. По экрану делится
только `presentation/table/` — с подпапками `cubit/` и `widgets/`, как у уже реализованных
`settings/` и `onboarding/`. Файл-заглушка `table_placeholder_page.dart` удаляется, ссылка на него
в `app/router/app_router.dart` заменяется на `TablePage`.

## Порядок реализации (для `/speckit-tasks`)

Срезы упорядочены так, чтобы каждый заканчивался работающим приложением и зелёными тестами:

1. **Фундамент фичи**: `dio`/`share_plus` в `pubspec`, `AiProxyFailure`, константы, `mood_scale`,
   новые ARB-ключи, `Character` + `CharacterCatalog` + ассет. Проверяется юнит-тестами каталога.
2. **US1 (P1)**: `TableCubit.load/setMood`, `TablePage`, шкала, разводка роута вместо заглушки,
   поведение в `readOnly`. После этого офлайн-ядро уже поставляется.
3. **US2 (P2)**: поле текста с лимитом и дебаунс-автосохранением (`flushDayText`, FR-008c),
   сетевой клиент + заглушка + `AiReactionRepository`, круглый стол, аватары, бабл с эффектом
   проговаривания, сохранение реакции. Текст дня не выделяется в отдельный срез: сам по себе он
   ничего не поставляет, он предусловие реакции (FR-014).
4. **US3 (P3)**: generation-счётчик, восстановление реплик при открытии, пометка «на прежний
   текст», реакция на смену дня.
5. **US4 (P4)**: пять веток отказов, fallback-реплики, inline-подача ошибок.
6. **US5 (P5)**: `ShareService` и действие у бабла.
7. **Финал**: a11y-тест, ручной прогон `quickstart.md`, запись новых грабель в
   `project/process/lessons-learned.md`, если что-то ломалось.

## Complexity Tracking

Нарушений Constitution Check нет — раздел не заполняется.
