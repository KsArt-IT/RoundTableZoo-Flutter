---

description: "Task list for 007-ai-proxy"
---

# Tasks: AI-прокси — живые реакции персонажей

**Input**: Design documents from `/specs/007-ai-proxy/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/react-api.md](./contracts/react-api.md),
[quickstart.md](./quickstart.md)

**Tests**: тестовые задачи включены. Основание — конституция, принцип VI (весь новый код покрыт,
задача с падающими тестами не считается выполненной) и research.md R18, где перечислено конкретное
покрытие. Это не «опциональные тесты по запросу», а требование проекта.

**Organization**: задачи сгруппированы по User Story из спеки, чтобы каждую можно было довести и
проверить отдельно.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: можно выполнять параллельно (разные файлы, нет незакрытых зависимостей)
- **[Story]**: к какой User Story относится задача (US1–US4)
- Пути к файлам указаны точно

## Path Conventions

Два проекта в одном репозитории (plan.md, «Structure Decision»):

- `proxy/` — служба на Cloudflare Workers (TypeScript), плоский набор модулей в `proxy/src/`
- `app/` — Flutter-приложение, слоистая раскладка (`lib/core/`, `lib/domain/`, `lib/data/`,
  `lib/presentation/`)

Команды `flutter` и `dart run build_runner` запускаются из `app/`, команды `npm` и `wrangler` — из
`proxy/` (CLAUDE.md).

## Что уже сделано и в задачи не входит

- **FR-028, FR-029** закрыты в фазе 004: `app/lib/core/network/ai_proxy_config.dart` читает
  `PROXY_BASE_URL` из `--dart-define` и роняет release-сборку без него. Задач нет, есть проверка в
  T064.
- Клиентская половина контракта (`AiReactionRepositoryImpl`, `AiReactionDto`, заготовленные реплики,
  выбор стаба) написана в 004 — здесь она расширяется, а не пишется заново.
- Раскрытие передачи текста AI в онбординге (`onboardingAiDisclosure`) существует с фазы 003 на трёх
  языках; в этой фиче добавляется только постоянно доступный пункт в настройках (FR-021).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: создать проект службы и его инфраструктуру. До конца фазы служба не отвечает ни на один
запрос — это каркас.

- [X] T001 Создать каркас проекта службы: `proxy/package.json` (npm-скрипты `dev`, `test`, `deploy`), `proxy/tsconfig.json` (strict), `proxy/.gitignore` с `.dev.vars` и `node_modules`
- [X] T002 [P] Добавить dev-зависимости `wrangler`, `vitest`, `@cloudflare/vitest-pool-workers`, `@cloudflare/workers-types` в `proxy/package.json`; рантайм-зависимостей не добавлять (research.md R2 — только Web Crypto и `fetch`)
- [X] T003 [P] Создать `proxy/vitest.config.ts` с пулом `@cloudflare/vitest-pool-workers`, привязанным к `proxy/wrangler.toml` (research.md R18)
- [X] T004 Создать `proxy/wrangler.toml` с секцией `[env.dev]`: биндинги D1 и KV, `ENVIRONMENT = "dev"`, `ALLOW_UNVERIFIED_INTEGRITY = "1"`, Cron Trigger раз в сутки. Продовая секция добавляется в T056
- [X] T005 [P] Создать `proxy/.dev.vars.example` с пустыми `GEMINI_API_KEY` и `GCP_SA_KEY` и комментарием, что настоящий `.dev.vars` в репозиторий не попадает (FR-032)
- [X] T006 Создать миграцию `proxy/migrations/0001_init.sql` — таблицы `rate_limits` и `global_limits` по data-model.md §1.1–1.2 (первичные ключи «сутки + installId» и «сутки + модель»)
- [X] T007 [P] Дополнить `CLAUDE.md` в корне: строка про `proxy/` в «Карте репозитория» и строка про `specs/007-ai-proxy` в таблице реализованных фич (plan.md, «Structure Decision»)

**Checkpoint**: `npm install` и `npx wrangler dev --env dev` из `proxy/` поднимаются без ошибок.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: типы контракта, чтение конфига, валидация запроса и маршрутизация — то, на что
опирается каждая User Story.

**⚠️ CRITICAL**: ни одна задача из Phase 3+ не может начаться раньше конца этой фазы.

- [X] T008 [P] Создать `proxy/src/types.ts` — типы `ReactRequest`, `ReactResponse`, `ErrorResponse`, перечисление кодов отказа (`bad_request`, `integrity_failed`, `rate_limited`, `ai_disabled`, `invalid_ai_response`, `internal`) и набор значений тона, совпадающий с `ReactionTone` клиента буква в букву (contracts/react-api.md §3, FR-004a)
- [X] T009 [P] Создать `proxy/src/day.ts` — вычисление ключа суток `yyyy-mm-dd` в UTC и порога очистки «минус 7 суток». Ключ вычисляется один раз за запрос и передаётся значением (research.md R9, конституция IV)
- [X] T010 Создать `proxy/src/validate.ts` — разбор и валидация тела по contracts/react-api.md §1: `installId` 32 hex, `characterId` из конфига промптов, `moodScore` 1–5, `dayText` непустой после trim и ≤ 2000 символов, `attempt` целое ≥ 0 (отсутствует → 0). Все поля трактуются как недоверенный ввод (FR-007)
- [X] T011 Создать `proxy/src/config.ts` — чтение `config:app` и `config:prompts` из KV. Отсутствие ключа → значения по умолчанию из data-model.md §1.3 (обе модели, 15/400, `aiEnabled: true`); **недоступность хранилища или непригодное для разбора значение → `500 internal`**, а не работа на дефолтах (data-model.md §1.3, решение CHK020)
- [X] T012 Создать `proxy/src/index.ts` — обработчики `fetch` (маршрут `POST /react`, остальное → 404) и `scheduled` (заглушка, наполняется в T044); единая сборка ответа об отказе по формату contracts/react-api.md §4
- [X] T013 [P] Написать тесты валидации и конфига в `proxy/test/validate.test.ts` и `proxy/test/config.test.ts`: каждое нарушение §1 даёт `400`; отсутствие ключа KV даёт дефолты; недоступный KV даёт `500`

**Checkpoint**: служба принимает запрос, отклоняет некорректный и читает конфиг. К Gemini ещё не ходит.

---

## Phase 3: User Story 1 — Персонаж отвечает по-настоящему (Priority: P1) 🎯 MVP

**Goal**: тап по персонажу приводит к настоящей реплике AI — по тексту дня и оценке настроения, в
характере зверя, с ротацией образов при повторном тапе.

**Independent Test**: поднять службу локально (`--env dev`, подтверждение подлинности не требуется),
запустить приложение с `--dart-define=PROXY_BASE_URL=http://10.0.2.2:8787`, написать текст дня и
тапнуть по персонажу → приходит реплика по существу написанного; тап по другому зверю на том же
тексте даёт другой тон; повторный тап по тому же зверю — другой образ.

### Tests for User Story 1

- [X] T014 [P] [US1] Тест сборки промпта в `proxy/test/prompt.test.ts`: префикс + персона + якорь склеиваются в заданном порядке; `attempt` 0..5 даёт шесть **разных** якорей; седьмой замыкает круг на первый (FR-002b, SC-003a)
- [X] T015 [P] [US1] Тест валидации ответа модели в `proxy/test/gemini.test.ts`: `mood` вне набора отбраковывается; `intensity` со значением `2` и `NaN` приводится клампом к 0.0–1.0; `finishReason: MAX_TOKENS` → один повтор → `422`; `character` берётся из запроса, а не из ответа модели (FR-004a–FR-004c, research.md R6, R16)
- [X] T016 [P] [US1] Тест обрезки реплики в `proxy/test/gemini.test.ts`: превышение `maxReplyLength` из `config:prompts` режется по границе слова, не по символу (FR-006, FR-006a)
- [X] T017 [P] [US1] Контрактный тест `200 OK` в `proxy/test/react.test.ts`: корректный запрос при подменённом `fetch` к Gemini даёт ответ формы §3 контракта
- [X] T018 [P] [US1] Тест счётчика попыток в `app/test/presentation/table_cubit_test.dart` (`bloc_test`): счётчик по персонажу восстанавливается при загрузке экрана из сохранённых реакций дня, растёт на настоящем ответе AI и **не растёт** на заготовленной реплике (research.md R20, R21, FR-001b)

### Implementation for User Story 1

- [X] T019 [P] [US1] Создать `proxy/src/prompt.ts` — сборка промпта из `commonPrefix`, персоны и якоря; выбор якоря `anchors[(dayOfYear + attempt) % anchors.length]`, замыкание круга после исчерпания набора (research.md R15, FR-002b)
- [X] T020 [P] [US1] Создать `proxy/src/models.ts` — выбор модели строго по приоритету из `models`; чередование не применяется (FR-007a, research.md R19). Учёт по счётчикам подключается в T039
- [X] T021 [US1] Создать `proxy/src/gemini.ts` — вызов `generateContent` с `thinkingLevel: "minimal"`, `responseMimeType: "application/json"` и явной `responseSchema` из трёх полей; `temperature` не задаётся; разбор полезной нагрузки из `candidates[0].content.parts[0].text` (research.md R6)
- [X] T022 [US1] Дополнить `proxy/src/gemini.ts` валидатором ответа: проверка `finishReason == STOP`, набора `mood`, непустоты `reply`, кламп `intensity`, подстановка `character` из запроса, один повтор при непригодном ответе, затем `422` (FR-004, FR-005, research.md R16)
- [X] T023 [US1] Создать `proxy/src/react.ts` — обработчик `POST /react` по порядку шагов contracts/react-api.md §2; на этой фазе реализуются шаги 1, 2, 6, 7 (проверка подлинности и счётчики подключаются в US2)
- [X] T024 [US1] Наполнить KV-ключ `config:prompts` рабочими текстами: общий префикс с семью правилами (research.md R15) и по 6 якорей на каждого из `cat`, `dog`, `crocodile`, `hippo` плюс `maxReplyLength`. Черновики брать из `project/experiments/gemini_prompt_probe.sh`; каждый якорь перечитать на двусмысленность (ловушка из R15)
- [X] T025 [P] [US1] Расширить `app/lib/core/network/ai_proxy_client.dart`: `react` получает параметры `moodScore` и `attempt`, `DioAiProxyClient` кладёт их в тело запроса
- [X] T026 [P] [US1] Расширить `app/lib/core/network/stub_ai_proxy_client.dart`: принимает новые параметры, реплика заметно меняется при росте `attempt` — иначе заглушка перестаёт быть полезной для проверки ротации
- [X] T027 [US1] Расширить `app/lib/domain/repositories/ai_reaction_repository.dart` и `app/lib/data/repositories/ai_reaction_repository_impl.dart`: `requestReaction` получает `moodScore` и `attempt` и пробрасывает их в клиент (research.md R20)
- [X] T028 [US1] Добавить счётчик попыток по персонажу в `app/lib/presentation/table/cubit/table_cubit.dart` (`Map<String, int>`): заполняется при загрузке из уже читаемых реакций дня, растёт только на настоящих ответах AI, передаётся в репозиторий вместе с `moodScore` (research.md R20, R21)
- [X] T029 [US1] Обновить `specs/004-table-screen/contracts/ai-proxy-client.md` §2 и §5 под новые параметры `moodScore` и `attempt` — контракт фазы 004 сейчас описывает старую сигнатуру (research.md R20)

**Checkpoint**: против локальной службы приложение получает настоящие реплики. Защиты ещё нет —
служба открыта, лимитов не ведёт.

---

## Phase 4: User Story 2 — Ключ и бюджет защищены (Priority: P1)

**Goal**: ключа нет в клиенте, запрос без действительного подтверждения подлинности отклоняется,
суточные лимиты ведутся атомарно и раздельно по моделям, AI-функцию можно выключить конфигом.

**Independent Test**: обратиться к продовой службе минуя приложение → отказ без обращения к
AI-провайдеру; превысить персональный предел → отказ с признаком «персональный лимит», другое
устройство продолжает работать; выключить `aiEnabled` → отказ «функция отключена» в течение минуты.

### Tests for User Story 2

- [X] T030 [P] [US2] Контрактные тесты кодов отказа в `proxy/test/react.test.ts`: `403` без токена и с непроходящим verdict, `429 scope=device`, `429 scope=global`, `503 ai_disabled` (contracts/react-api.md §4)
- [X] T031 [P] [US2] Тест порядка проверок в `proxy/test/react.test.ts`: при `aiEnabled: false` к Gemini обращения нет; при непройденной подлинности счётчики не трогаются (FR-016)
- [X] T032 [P] [US2] Тест атомарности в `proxy/test/limits.test.ts` на **настоящем** D1 пула Workers: параллельные инкременты с одного устройства не дают превысить персональный предел, параллельные инкременты с разных устройств — общий предел по модели (FR-013)
- [X] T033 [P] [US2] Тест раздельности счётчиков в `proxy/test/limits.test.ts`: в `global_limits` появляется по строке на модель, исчерпание основной не блокирует резервную (FR-012)
- [X] T034 [P] [US2] Тест очистки в `proxy/test/cron.test.ts`: после принудительного запуска `scheduled` не остаётся записей с ключом суток старше 7 дней (FR-018)
- [X] T035 [P] [US2] Тест кэша токена в `app/test/core/integrity_token_provider_test.dart`: десять вызовов `token()` дают одно обращение к платформе; одновременные вызовы при пустом кэше — тоже одно; `invalidate()` заставляет запросить свежий (SC-005a, data-model.md §4.1)
- [X] T036 [P] [US2] Тест повтора при `403` в `app/test/core/ai_proxy_client_test.dart`: ровно один повтор со свежим токеном, при повторном `403` — отказ без цикла, общий таймаут покрывает обе попытки (FR-010a)

### Implementation for User Story 2

- [X] T037 [P] [US2] Создать `proxy/src/integrity.ts` — подпись JWT RS256 через Web Crypto ключом сервис-аккаунта, обмен на access token у `oauth2.googleapis.com/token`, кэш в KV `gcp:token` с TTL 50 минут (research.md R5)
- [X] T038 [US2] Дополнить `proxy/src/integrity.ts` вызовом `decodeIntegrityToken` и проверкой verdict по трём условиям contracts/react-api.md §5; иначе `403`, к Gemini не ходим (FR-009)
- [X] T039 [US2] Создать `proxy/src/limits.ts` — атомарные инкременты `rate_limits` и `global_limits` одним `INSERT … ON CONFLICT … RETURNING count` (data-model.md §1.1–1.2); недоступность хранилища счётчиков → `500`, а не проход мимо лимитов (FR-013, FR-016)
- [X] T040 [US2] Подключить в `proxy/src/react.ts` шаги 2–5 порядка: kill switch → подтверждение подлинности → персональный лимит → общий лимит с выбором модели; ключ суток вычисляется один раз перед шагом 4; счётчик при провале вызова Gemini не откатывается (FR-016, research.md R9)
- [X] T041 [P] [US2] Создать `app/lib/core/integrity/integrity_token_provider.dart` — интерфейс по data-model.md §4.1 (`token()`, `invalidate()`) и `UnsupportedIntegrityTokenProvider`, всегда возвращающий `null` (research.md R14)
- [X] T042 [P] [US2] Создать `app/lib/core/integrity/play_integrity_token_provider.dart` — `MethodChannel` к Play Integrity, кэш на процесс, одновременные вызовы при пустом кэше дают один запрос к платформе; ошибка платформы даёт `null`, а не исключение наружу (research.md R3, R4)
- [X] T043 [US2] Создать `app/android/app/src/main/kotlin/life/studyway/roundtablezoo/IntegrityChannel.kt` с единственным методом `requestToken` поверх `com.google.android.play:integrity` и зарегистрировать его в `MainActivity.configureFlutterEngine`; добавить зависимость в `app/android/app/build.gradle.kts`
- [X] T044 [US2] Реализовать `scheduled` в `proxy/src/index.ts` — удаление записей старше 7 суток из обеих таблиц (FR-018, research.md R10)
- [X] T045 [US2] Подключить токен в `app/lib/core/network/ai_proxy_client.dart`: `DioAiProxyClient` получает `IntegrityTokenProvider`, кладёт токен в тело, при `403` один раз сбрасывает кэш и повторяет запрос; общий таймаут 15 с оборачивает обе попытки (FR-010a, research.md R13)
- [X] T046 [US2] Зарегистрировать провайдер в `app/lib/core/di/injection_module.dart` — выбор по `defaultTargetPlatform` рядом с существующим выбором `AiProxyClient`, передача в `DioAiProxyClient`
- [X] T047 [US2] Добавить пункт-раскрытие передачи текста AI в `app/lib/presentation/settings/` с текстом `onboardingAiDisclosure` — постоянно доступный канал раскрытия, в том числе для тех, кто прошёл онбординг до появления AI (FR-021)

**Checkpoint**: служба защищена, ключ только на сервере, лимиты работают. Отказы пока доходят до
пользователя невнятно — это US3.

---

## Phase 5: User Story 3 — Отказ AI не ломает приложение (Priority: P2)

**Goal**: каждый из семи исходов даёт своё определённое поведение — понятное сообщение или
заготовленную реплику, без краша, пустого бабла и зависшего ожидания.

**Independent Test**: смоделировать по очереди все семь исходов (нет сети, таймаут, персональный
лимит, общий лимит, функция отключена, отклонена подлинность, непригодный ответ) → на каждый своё
поведение, запись дня остаётся сохранённой, тап по другому персонажу после отказа работает.

### Tests for User Story 3

- [X] T048 [P] [US3] Тест маппинга кодов в `app/test/data/ai_reaction_repository_test.dart`: `403` → `integrityRejected`; `429` с `scope: device` → `rateLimitedDevice`, с `scope: global` → `rateLimitedGlobal`; `503` → `aiDisabled`; `422` и любой другой статус → `invalidResponse`
- [X] T049 [P] [US3] Тест экрана в `app/test/presentation/table_screen_test.dart`: новые сообщения отображаются локализованными; на `invalidResponse` показывается заготовленная реплика с пометкой, а не текст ошибки (FR-024)
- [X] T050 [P] [US3] Тест независимости персонажей в `app/test/presentation/table_cubit_test.dart`: отказ по одному персонажу не переводит в состояние отказа остальные места за столом (FR-026)
- [X] T051 [P] [US3] Тест переключения на резервную модель в `proxy/test/models.test.ts`: `429` от Gemini → один повтор с задержкой ≤ 2 с → следующая модель; исчерпание списка → `422`, а не `rate_limited` (FR-007b, research.md R19)

### Implementation for User Story 3

- [X] T052 [US3] Расширить `AiProxyFailure` в `app/lib/core/errors/app_failure.dart`: `rateLimited` → `rateLimitedDevice`, добавить `rateLimitedGlobal` и `integrityRejected`, дописать ветки `localizedMessage` (research.md R12)
- [X] T053 [US3] Разложить коды в `_codeFor` в `app/lib/data/repositories/ai_reaction_repository_impl.dart`: `403` → `integrityRejected`, `429` → device/global по полю `scope` тела ответа
- [X] T054 [P] [US3] Добавить ключи `tableAiRateLimitedGlobalError` и `tableAiUnavailableError` в `app/lib/l10n/intl_ru.arb`, `intl_en.arb`, `intl_uk.arb`; тексты без технических подробностей проверки подлинности, адресов службы и кодов провайдера (FR-027)
- [X] T055 [US3] Реализовать переключение на резервную модель в `proxy/src/models.ts` и `proxy/src/gemini.ts`: `429` от провайдера → повтор с задержкой ≤ 2 с → следующая модель по приоритету → `422`; все повторы укладываются в клиентский бюджет 15 с, а не продлевают его (FR-007b)

**Checkpoint**: все семь исходов различимы для пользователя, стол не блокируется отказом.

---

## Phase 6: User Story 4 — Разработка и проверка без риска для прода (Priority: P3)

**Goal**: отладочный контур со своими счётчиками, конфигурацией и секретами, где сценарий проходится
на эмуляторе; послабление проверки подлинности недостижимо в проде.

**Independent Test**: прогнать сценарий на эмуляторе против отладочного контура — реплики приходят;
убедиться, что его счётчики и конфиг не пересекаются с продовыми, а в продовом развёртывании
послабление отсутствует как возможность.

- [X] T056 [US4] Добавить секцию `[env.production]` в `proxy/wrangler.toml` — отдельные D1 и KV, `ENVIRONMENT = "production"`, **без** `ALLOW_UNVERIFIED_INTEGRITY`; отладочные биндинги в неё не переносятся (FR-030, FR-031, research.md R11)
- [X] T057 [US4] Реализовать в `proxy/src/react.ts` пропуск проверки подлинности только при одновременном `ENVIRONMENT === "dev"` **и** заданном `ALLOW_UNVERIFIED_INTEGRITY`; в проде обе переменные отсутствуют, поэтому состояние недостижимо (contracts/react-api.md §1)
- [X] T058 [P] [US4] Тест продовой конфигурации в `proxy/test/env.test.ts`: разбор `wrangler.toml` подтверждает, что секция production не содержит `ALLOW_UNVERIFIED_INTEGRITY` и не делит биндинги с dev (FR-031)
- [X] T059 [P] [US4] Написать `proxy/README.md` — поднять локально, наполнить KV, применить миграции, развернуть оба контура; секреты только через `wrangler secret put` (FR-032)

**Checkpoint**: оба контура разделены, отладка не расходует продовый бюджет.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T060 Прогнать `cd proxy && npm test` и `cd app && flutter analyze && flutter test` — оба прогона обязаны быть зелёными (конституция, «Рабочий процесс», gate 5)
- [X] T061 Пройти [quickstart.md](./quickstart.md) §2 целиком — ручное зеркало контрактных тестов, включая выборку на 20 реплик по SC-003b и проверку отсутствия `thoughtsTokenCount` в `usageMetadata`
- [ ] T062 Пройти [quickstart.md](./quickstart.md) §4 и §5 на устройстве — десять пунктов сценария, включая независимость персонажей (FR-026) и единственное обращение за подтверждением подлинности на сессию (SC-005a)
- [X] T063 Проверить приватность после прогона: в `rate_limits`, `global_limits`, ключах KV и выводе `wrangler tail` нет ни одного фрагмента текста дня (FR-019, SC-009)
- [ ] T064 Развернуть продовый контур по quickstart.md §7 и проверить на собранном APK: запрос без токена даёт `403`, release-сборка без `PROXY_BASE_URL` падает (FR-029), в APK не находится ключ Gemini (SC-004)
- [X] T065 [P] Дописать в `project/process/lessons-learned.md` грабли этой фазы: двусмысленные якоря (research.md R15), молчаливая деградация неизвестного `mood` в `neutral` (R6), два разных `429` (R19)
- [ ] T066 Сверить суточные квоты Gemini с дашбордом провайдера перед релизом и обновить числа в `project/architecture/backend-proxy.md` §6.1 и в `config:app`, если они изменились (SC-010, quickstart.md §8)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: без зависимостей
- **Foundational (Phase 2)**: после Phase 1 — **блокирует все User Stories**
- **US1 (Phase 3)**: после Phase 2
- **US2 (Phase 4)**: после Phase 2; T045 трогает тот же файл, что и T025 (`ai_proxy_client.dart`), поэтому идёт после US1
- **US3 (Phase 5)**: после Phase 2; T053 опирается на `_codeFor`, расширенный в US1/US2, а T055 — на `models.ts` из T020
- **US4 (Phase 6)**: после Phase 2; T057 правит `react.ts`, поэтому после T040
- **Polish (Phase 7)**: после всех нужных историй

### User Story Dependencies

- **US1 (P1)** — независима, это MVP. Проверяется против локального контура, где подтверждение подлинности не требуется
- **US2 (P1)** — независима по проверке, но на клиенте делит `ai_proxy_client.dart` с US1: очередь по файлу, а не по смыслу
- **US3 (P2)** — независима; часть исходов уже работает с фазы 004, здесь добавляются три новых кода
- **US4 (P3)** — независима; формализует разделение контуров, которое Phase 1 завела в минимальном виде (`[env.dev]`), чтобы US1 было на чём проверять

### Parallel Opportunities

- Phase 1: T002, T003, T005, T007 параллельны
- Phase 2: T008 и T009 параллельны; T010 и T011 — после T008
- Phase 3: тесты T014–T018 параллельны между собой; T019, T020, T025, T026 параллельны (разные файлы)
- Phase 4: тесты T030–T036 параллельны; T037, T041, T042 параллельны
- Phase 5: тесты T048–T051 параллельны; T054 параллелен T052/T053
- Служба (`proxy/`) и приложение (`app/`) не делят ни одного файла — при двух исполнителях фазы 3–5 делятся по этой границе

## Parallel Example: User Story 1

```bash
# Тесты US1 — все сразу:
Task: "Тест сборки промпта в proxy/test/prompt.test.ts"
Task: "Тест валидации ответа модели в proxy/test/gemini.test.ts"
Task: "Тест обрезки реплики в proxy/test/gemini.test.ts"
Task: "Контрактный тест 200 OK в proxy/test/react.test.ts"
Task: "Тест счётчика попыток в app/test/presentation/table_cubit_test.dart"

# Независимые модули US1:
Task: "Создать proxy/src/prompt.ts"
Task: "Создать proxy/src/models.ts"
Task: "Расширить app/lib/core/network/ai_proxy_client.dart"
Task: "Расширить app/lib/core/network/stub_ai_proxy_client.dart"
```

## Implementation Strategy

### MVP First (US1)

1. Phase 1 → Phase 2 → Phase 3.
2. **Остановиться и проверить**: приложение на эмуляторе против локальной службы получает настоящие
   реплики, разные по персонажам, с ротацией образов при повторном тапе.
3. Это уже демонстрируемый продукт — но **не публикуемый**: служба на этом шаге открыта, и
   выкладывать её наружу нельзя (конституция, принцип V).

### Incremental Delivery

1. Setup + Foundational → каркас службы.
2. + US1 → живые реплики (MVP, только локально).
3. + US2 → служба защищена, ключ и бюджет в безопасности — **минимум, допустимый для публикации**.
4. + US3 → отказы понятны пользователю.
5. + US4 → отладка не трогает прод.
6. Polish → прогоны, развёртывание, сверка квот.

### Parallel Team Strategy

Граница `proxy/` ↔ `app/` — естественный раздел: общих файлов нет, связывает их только контракт
`/react`. При двух исполнителях один ведёт службу (T019–T024, T037–T040, T044, T055), второй —
клиента (T025–T029, T041–T043, T045–T047, T052–T054).

## Notes

- Всего задач: **66**. По историям: US1 — 16, US2 — 18, US3 — 8, US4 — 4; Setup — 7,
  Foundational — 6, Polish — 7
- `[P]` = разные файлы, нет незакрытых зависимостей
- Коммит после каждой задачи или логической группы
- Тесты в этой фиче не опциональны: конституция VI + research.md R18
- Задача с падающими тестами не считается выполненной

---

## Phase 8: Convergence

- [X] T067 Добавить в `proxy/test/gemini.test.ts` (или отдельный файл) тест, утверждающий, что
  `REACTION_TONES` (`proxy/src/types.ts`) буквально совпадает со списком значений
  `ReactionTone` (`app/lib/domain/value_objects/reaction_tone.dart`: `neutral`, `warm`,
  `playful`, `dry`, `sad`, `encouraging`) — сейчас оба списка совпадают, но ничто не поймает
  будущее расхождение одной стороны без другой (research.md R18, missing)
