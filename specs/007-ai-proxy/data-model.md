# Data Model — 007-ai-proxy

**Feature**: [spec.md](./spec.md) | **Решения**: [research.md](./research.md) | **Дата**: 2026-08-22
**Обновлено** под `backend-proxy.md` v0.3: ключ `global_limits`, состав KV-конфига, новый ключ
`config:prompts`, новые поля запроса на стороне клиента.

Сущности фичи живут в трёх местах: таблицы D1 и ключи KV на стороне службы, типы контракта на
границе, новые классы в `core/` на стороне приложения. Локальная схема Drift **не меняется**:
`user_settings.installId` (фаза 002) и `character_reactions` (фаза 004) уже есть и достаточны.

---

## 1. Хранилище службы

### 1.1 D1 — `rate_limits`

```sql
CREATE TABLE rate_limits (
  day        TEXT    NOT NULL,   -- 'yyyy-mm-dd', UTC (research.md R9)
  install_id TEXT    NOT NULL,   -- как пришёл от клиента, после проверки подлинности
  count      INTEGER NOT NULL,
  PRIMARY KEY (day, install_id)
);
```

| Поле | Правила |
|---|---|
| `day` | ключ суток, вычисляется один раз в начале обработки запроса (R9) |
| `install_id` | 32 hex-символа из `user_settings.installId`; форма проверяется до записи |
| `count` | ≥ 1; инкремент и чтение — одним запросом (R8) |

Инкремент с проверкой:

```sql
INSERT INTO rate_limits (day, install_id, count) VALUES (?1, ?2, 1)
  ON CONFLICT(day, install_id) DO UPDATE SET count = count + 1
  RETURNING count;
```

Строка живёт 7 суток, дальше удаляется Cron Trigger'ом (R10). Персональных данных не содержит:
`install_id` не связан ни с аккаунтом, ни с устройством (FR-020).

### 1.2 D1 — `global_limits`

```sql
CREATE TABLE global_limits (
  day   TEXT    NOT NULL,   -- 'yyyy-mm-dd', UTC
  model TEXT    NOT NULL,   -- квоты провайдера считаются по моделям отдельно
  count INTEGER NOT NULL,
  PRIMARY KEY (day, model)
);
```

Тот же приём инкремента, тот же ключ суток, та же очистка. Ключ — пара «сутки + модель», а не только
сутки: без раздельного учёта служба не может понять, что основная модель исчерпана, а резервная
свободна, и переключение по research.md R19 не работает. Строк в сутки — по одной на модель.

### 1.3 KV — `config:app`

```json
{
  "aiEnabled": true,
  "models": ["gemini-3.5-flash-lite", "gemini-3.1-flash-lite"],
  "dailyCapOverride": 400,
  "perDeviceCapOverride": 15
}
```

| Поле | Тип | Отсутствует → | Смысл |
|---|---|---|---|
| `aiEnabled` | bool | `true` | kill switch (FR-014) |
| `models` | список строк, по приоритету | значение по умолчанию из кода (обе модели) | какие модели и в каком порядке пробовать (FR-007a). Точные версии, без `*-latest` |
| `dailyCapOverride` | int > 0 | 400 | общий суточный предел **на каждую модель** (FR-012) |
| `perDeviceCapOverride` | int > 0 | 15 | персональный суточный предел (FR-011) |

Обе модели из спеки (Assumptions) присутствуют в конфиге **с первого развёртывания**: SC-006a
требует, чтобы при исчерпании суточной квоты основной модели запросы продолжали выполняться на
резервной «без вмешательства человека», а список из одной модели этого не даёт — потребовалась бы
ручная правка конфига в момент отказа. Порядок элементов = приоритет (FR-007a); менять список
можно правкой конфига, без правки кода и без развёртывания.

Читается на каждый запрос. Значения по умолчанию из таблицы применяются, когда **ключа нет** —
это штатное состояние до первой записи конфига. Если же хранилище конфигурации **недоступно** или
значение непригодно для разбора, запрос отклоняется предсказуемым отказом (`500 internal`), а не
обрабатывается на дефолтах: спека (Edge Cases, «Хранилище счётчиков или конфигурации временно
недоступно») требует именно отказа, и это решение подтверждено ревью чеклиста 2026-08-23 (CHK020).
Тот же принцип для **хранилища счётчиков**: недоступно — отказ, а не проход мимо лимитов.

### 1.4 KV — `config:prompts`

Все тексты промпта (research.md R7, FR-002a): общий префикс, персона каждого зверя, по 6 якорей на
зверя и предел длины реплики.

```json
{
  "commonPrefix": "…правила из research.md R15…",
  "personas": {
    "hippo": {
      "systemPrompt": "…",
      "anchors": ["…", "…", "…", "…", "…", "…"],
      "maxReplyLength": 220
    }
  }
}
```

| Поле | Правила |
|---|---|
| `commonPrefix` | непустая строка; содержит все семь правил префикса (research.md R15) |
| `personas` | ключи — `cat`, `dog`, `crocodile`, `hippo`; неизвестный ключ в запросе → `400` |
| `anchors` | ≥ 6 элементов; выбор — `anchors[(dayOfYear + attempt) % anchors.length]`. Остаток по модулю и есть требуемое FR-002b замыкание круга: после исчерпания набора перебор идёт с начала |
| `maxReplyLength` | int > 0; **владелец значения** — этот конфиг, не `characters.json` (research.md R7) |

Правка формулировки — `wrangler kv key put`, без развёртывания и без релиза приложения. Рабочие
черновики текстов — `project/experiments/gemini_prompt_probe.sh`.

### 1.5 KV — `gcp:token`

Кэш access token'а Google, TTL 50 минут при часе жизни (R5). Единственная регулярная запись в KV.
Значение — сам токен; ничего пользовательского не содержит.

---

## 2. Типы контракта

Полное описание запроса и ответов — [contracts/react-api.md](./contracts/react-api.md). Здесь —
только состав сущностей.

- **ReactRequest**: `installId`, `characterId`, `moodScore`, `dayText`, `attempt`,
  `integrityToken?`. `moodScore` (1–5) обязателен; `attempt` отсутствует → 0.
  `integrityToken` необязателен на уровне разбора и обязателен на уровне проверки — отсутствие
  допустимо только в отладочном контуре (R11, R14).
- **ReactResponse**: `character`, `mood`, `reply`, `intensity` — форма не меняется относительно фазы
  004, поэтому `AiReactionDto` на клиенте остаётся как есть.
- **ErrorResponse**: `error` + необязательные `scope` (для `rate_limited`) и `retryAfterSeconds`.

## 3. Роль персонажа

Живёт в KV-ключе `config:prompts` (§1.4), не в коде службы и не в ассете приложения. Состав —
`systemPrompt`, `anchors` (≥ 6), `maxReplyLength`.

**Связь с клиентским ассетом**: `assets/characters/characters.json` и `config:prompts` описывают
одного и того же персонажа непересекающимися полями — общий у них только `id`. Единственное
пересечение — `maxReplyLength`: владельцем значения назначен `config:prompts` (research.md R7), поле
в ассете остаётся ограничением на стороне отображения и в `/react` не передаётся. Расхождение
безопасно в одну сторону — служба режет строже, чем показывает клиент — и покрыто тестом на стороне
службы.

## 4. Новое на стороне приложения

### 4.1 `IntegrityTokenProvider` (`app/lib/core/integrity/`)

```dart
abstract interface class IntegrityTokenProvider {
  /// Кэшированный токен на весь процесс (Clarifications Q2). `null` —
  /// платформа не поддерживает механизм (R14) или токен получить не удалось;
  /// запрос уходит без него и будет отклонён продовой службой.
  Future<String?> token();

  /// Сбрасывает кэш — вызывается ровно один раз при `403` от службы
  /// (FR-010a), после чего [token] выдаёт свежий.
  void invalidate();
}
```

Реализации:

| Класс | Когда | Поведение |
|---|---|---|
| `PlayIntegrityTokenProvider` | Android | `MethodChannel` к Play Integrity, кэш в поле, один запрос на процесс (R3, R4) |
| `UnsupportedIntegrityTokenProvider` | не-Android | всегда `null`, `invalidate()` — пустышка (R14) |

Выбор — в `InjectionModule` по `defaultTargetPlatform`, рядом с уже существующим выбором
`AiProxyClient` (стаб против настоящего).

Состояния кэша: `нет токена` → (`token()`) → `есть токен` → (`invalidate()`) → `нет токена`.
Одновременные `token()` при пустом кэше MUST дать один запрос к платформе, а не N — иначе SC-005a
не выполняется на экране, где пользователь тапает по двум персонажам подряд.

### 4.2 Изменения в существующих типах

| Файл | Изменение |
|---|---|
| `core/errors/app_failure.dart` | `AiProxyFailure`: `rateLimited` → `rateLimitedDevice`, добавлены `rateLimitedGlobal`, `integrityRejected`; ветки `localizedMessage` (R12) |
| `core/network/ai_proxy_client.dart` | `AiProxyClient.react` получает параметры `moodScore` и `attempt`; `DioAiProxyClient` получает `IntegrityTokenProvider`, кладёт токен в тело, повторяет один раз при `403` (R13); общий таймаут оборачивает обе попытки |
| `domain/repositories/ai_reaction_repository.dart` | `requestReaction` получает `moodScore` и `attempt` (R20) |
| `data/repositories/ai_reaction_repository_impl.dart` | пробрасывает новые параметры; `_codeFor`: `403` → `integrityRejected`, `429` → device/global по полю `scope` тела ответа |
| `presentation/table/cubit/table_cubit.dart` | счётчик попыток по персонажу (`Map<String, int>`), заполняется при загрузке из уже читаемых реакций дня, растёт только на настоящих ответах AI (R20, R21); передаёт `moodScore` и `attempt` в репозиторий |
| `core/network/stub_ai_proxy_client.dart` | принимает новые параметры; чтобы заглушка оставалась полезной, её реплика должна заметно меняться при росте `attempt` |
| `l10n/intl_{ru,en,uk}.arb` | `tableAiRateLimitedGlobalError`, `tableAiUnavailableError` |
| `core/di/injection_module.dart` | регистрация `IntegrityTokenProvider`, передача его в `DioAiProxyClient` |
| `presentation/settings/` | пункт с текстом `onboardingAiDisclosure` — постоянно доступное раскрытие (FR-021) |

Не меняются: `AiReactionDto` (форма ответа та же), `CharacterReaction`, `TableState`, схема Drift.

**Поправка к первой редакции этого файла**: там утверждалось, что `AiProxyClient`,
`AiReactionRepository` и `TableCubit` остаются нетронутыми. После `backend-proxy.md` v0.3 это
неверно — появление `moodScore` и `attempt` в запросе задевает всю цепочку до Cubit-а включительно.
Контракт `specs/004-table-screen/contracts/ai-proxy-client.md` §2 и §5 нужно обновить в рамках этой
фичи.

### 4.3 Android-сторона

`app/android/app/src/main/kotlin/life/studyway/roundtablezoo/IntegrityChannel.kt` — обработчик
`MethodChannel` с единственным методом `requestToken`, поверх `com.google.android.play:integrity`.
Регистрируется в `MainActivity.configureFlutterEngine`. Ошибки платформы возвращаются как
`PlatformException` и превращаются в `null` на стороне Dart — приложение из-за них не падает
(FR-025).
