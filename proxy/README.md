# roundtablezoo-ai-proxy

Служба-посредник к Gemini на Cloudflare Workers. Единственное место, где живёт ключ Gemini —
клиент его никогда не видит. Контракт: [`../specs/007-ai-proxy/contracts/react-api.md`](../specs/007-ai-proxy/contracts/react-api.md).
Общая схема и решения — [`../project/architecture/backend-proxy.md`](../project/architecture/backend-proxy.md),
[`../specs/007-ai-proxy/research.md`](../specs/007-ai-proxy/research.md).

## Что нужно иметь заранее

- Аккаунт Cloudflare (free-план, карта не нужна) и `npx wrangler login`.
- Ключ Gemini API (Google AI Studio, free tier).
- Сервис-аккаунт GCP с правом вызывать Play Integrity API, JSON-ключ.
- Приложение в Play Console с пакетом `life.studyway.roundtablezoo` (для Play Integrity).

## Локальная разработка (отладочный контур)

```bash
npm install
cp .dev.vars.example .dev.vars          # заполнить GEMINI_API_KEY и GCP_SA_KEY
```

Создать D1 и KV для контура `dev`, если ещё не созданы, и вписать их id в `wrangler.toml`
(`[[env.dev.d1_databases]]` / `[[env.dev.kv_namespaces]]` — плейсхолдеры `<REPLACE_WITH_...>`):

```bash
npx wrangler d1 create roundtablezoo-ai-dev
npx wrangler kv namespace create CONFIG --env dev
```

Биндинги объявлены только внутри `[env.dev]` и `[env.production]`, корневой секции с ними нет,
поэтому **каждая** команда wrangler, работающая с D1 или KV, требует `--env`. Без него будет
`Couldn't find a D1 DB with the name or binding … in your wrangler.toml file`. Командам `kv key`
нужен вдобавок `--binding CONFIG` — иначе `Missing required option: exactly one of --binding and
--namespace-id must be provided`.

Применить миграции и запустить локально:

```bash
npx wrangler d1 migrations apply roundtablezoo-ai-dev --env dev --local
npm run dev                              # wrangler dev --env dev
```

Наполнить KV-конфиг (локально, флаг `--local`; для удалённого dev-неймспейса — без флага):

```bash
npx wrangler kv key put --binding CONFIG --env dev --local config:app --path=seed/config.app.json
npx wrangler kv key put --binding CONFIG --env dev --local config:prompts --path=seed/config.prompts.json
```

`seed/config.app.json` и `seed/config.prompts.json` — рабочие значения по умолчанию
(data-model.md §1.3–1.4); правка текста промпта на проде — такая же команда `kv key put` с
собственным JSON, без редеплоя (FR-002a).

Проверка «служба жива» — см. `../specs/007-ai-proxy/quickstart.md` §1–2 (curl-примеры на каждый
код ответа).

## Тесты

```bash
npm test          # vitest + @cloudflare/vitest-pool-workers, реальные D1/KV в эмуляции
npm run typecheck # tsc --noEmit, strict
```

Оба прогона обязаны быть зелёными (конституция, «Рабочий процесс», gate 5).

## Развёртывание (продовый контур)

Отдельные D1/KV от dev — **не переиспользовать** идентификаторы:

```bash
npx wrangler d1 create roundtablezoo-ai
npx wrangler kv namespace create CONFIG --env production
```

Вписать id в `wrangler.toml` (`[[env.production.d1_databases]]` /
`[[env.production.kv_namespaces]]`), затем:

```bash
npx wrangler secret put GEMINI_API_KEY --env production
npx wrangler secret put GCP_SA_KEY --env production
npx wrangler d1 migrations apply roundtablezoo-ai --env production --remote
npx wrangler kv key put --binding CONFIG --env production config:app --path=seed/config.app.json
npx wrangler kv key put --binding CONFIG --env production config:prompts --path=seed/config.prompts.json
npm run deploy    # wrangler deploy --env production
```

Секреты — только через `wrangler secret put`, никогда в `wrangler.toml` или `.dev.vars`
(последний в `.gitignore`, в репозиторий не попадает).

Проверить после развёртывания (quickstart.md §7): продовый `wrangler.toml` не содержит
`ALLOW_UNVERIFIED_INTEGRITY` (`proxy/test/env.test.ts` проверяет это автоматически при каждом
`npm test`), запрос без `integrityToken` возвращает `403`, а ключ Gemini не находится ни в каком
виде в собранном APK приложения.

## Структура

| Файл | Роль |
|---|---|
| `src/index.ts` | `fetch` (маршрутизация `/react`) + `scheduled` (очистка счётчиков раз в сутки) |
| `src/react.ts` | Порядок шагов `POST /react` целиком |
| `src/validate.ts` | Разбор и валидация тела запроса |
| `src/config.ts` | Чтение `config:app` / `config:prompts` из KV |
| `src/integrity.ts` | JWT → access token Google → `decodeIntegrityToken` |
| `src/limits.ts` | Атомарные инкременты `rate_limits` / `global_limits` |
| `src/models.ts` | Выбор модели по приоритету |
| `src/prompt.ts` | Сборка промпта: префикс + персона + якорь |
| `src/gemini.ts` | Вызов Gemini, валидация и обрезка ответа |
| `src/types.ts` | Типы контракта |
| `migrations/` | Схема D1 |
| `seed/` | Рабочие значения `config:app` / `config:prompts` для `wrangler kv key put` |
