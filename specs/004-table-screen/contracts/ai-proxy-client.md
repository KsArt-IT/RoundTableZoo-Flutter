# Contract — клиент ai-proxy

**Feature**: `specs/004-table-screen` | Источник истины по серверной стороне:
`project/architecture/backend-proxy.md` §4.

Этот контракт описывает **клиентскую** половину: что уходит, что принимается и во что превращается
каждый отказ. Сам прокси в этой фазе не создаётся (Clarifications Q1).

---

## 1. Транспорт

```
POST {PROXY_BASE_URL}/react
Content-Type: application/json
```

`PROXY_BASE_URL` — из `--dart-define=PROXY_BASE_URL=...` (research.md R2). Пустое значение
переводит DI на `StubAiProxyClient` (R14): сетевых вызовов нет вовсе. В release-сборке пустой адрес
недопустим — запуск обязан падать с явной ошибкой конфигурации (SC-012).

Клиент **не повторяет** неудачный запрос автоматически (FR-016a): повтор инициирует пользователь
тапом. Внутренний retry остаётся на прокси.

Таймауты: `connectTimeout` = 10 с, `receiveTimeout` = 15 с; поверх них — **общий бюджет запроса
15 с** (`AppConstants.aiRequestTimeout`), и обязательным пределом является именно он (FR-027a).
Сумма частных таймаутов не должна давать ожидание дольше общего бюджета: медленное соединение плюс
медленный ответ обязаны прерваться на 15-й секунде, а не на 25-й.

## 2. Запрос

**Обновлено фазой 007** (`specs/007-ai-proxy/research.md` R20): добавлены `moodScore` и `attempt`,
опционально — `integrityToken`.

```json
{
  "installId": "32 hex-символа из user_settings.installId",
  "characterId": "hippo",
  "moodScore": 2,
  "dayText": "Текст пользователя о своём дне",
  "attempt": 0,
  "integrityToken": "<токен Play Integrity, только Android — research.md R14>"
}
```

- `moodScore` — оценка настроения 1–5, та же, что сохранена в `DayEntry` (`TableCubit.setMood`).
  Модель на неё реагирует; без неё реплика теряет половину контекста (`specs/007-ai-proxy/contracts/react-api.md` §1).
- `attempt` — число уже полученных сегодня **настоящих** реплик этого персонажа
  (`TableCubit._attempts`, research.md R20/R21); фолбэк-реплики счётчик не увеличивают. Служба
  выбирает по нему образ для сравнения — это конструктивно закрывает FR-018 фазы 004 (повторный тап
  MUST давать новый вариант ответа).
- `integrityToken` — из `IntegrityTokenProvider` (`specs/007-ai-proxy/contracts/integrity-token-provider.md`);
  отсутствует в теле, если провайдер вернул `null` (не-Android, или платформенный сбой).
- `dayText` уходит ровно в том виде, в каком сохранён (уже нормализован `Validators.dayText`).
- Дневник и история реплик устройство не покидают (принцип V) — уходят только перечисленные выше
  поля.

## 3. Успешный ответ

```json
{
  "character": "hippo",
  "mood": "content",
  "reply": "Не спеши, всё пройдёт...",
  "intensity": 0.5
}
```

Правила разбора:

| Поле | Обязательность | Обработка |
|---|---|---|
| `character` | обязательно | должно совпасть с запрошенным `characterId`; несовпадение → `invalidResponse` |
| `mood` | необязательно | `ReactionTone.fromStorage(mood)` — неизвестное значение молча становится `neutral`, реплика не теряется |
| `reply` | обязательно | непустая строка после `trim()`; иначе `invalidResponse` |
| `intensity` | необязательно | число вне 0.0..1.0 или отсутствует → `0.5`; реплика не отбрасывается |

Разобранный ответ превращается в `CharacterReaction(isFallback: false, createdAt: clock.nowUtc())`
и сохраняется через `DiaryRepository.addReaction`.

## 4. Отказы → `AiProxyFailure`

**Обновлено фазой 007** (research.md R12): `rateLimited` разделён на `rateLimitedDevice`/
`rateLimitedGlobal` по полю `scope` тела `429`-ответа (`specs/007-ai-proxy/contracts/react-api.md` §4),
добавлен `integrityRejected` для `403`.

| Ситуация | Код `AiProxyFailure` | Что видит пользователь |
|---|---|---|
| `DioExceptionType.connectionError`, `connectionTimeout`, отсутствие сети | `network` | сообщение «нет сети» рядом со столом, слот возвращается в прежнее состояние |
| HTTP `403` | `integrityRejected` | «AI недоступен на этом устройстве» — не «лимит» и не заготовленная реплика |
| HTTP `429`, тело `{"scope": "device"}` или без разбираемого `scope` | `rateLimitedDevice` | «лимит на сегодня» (личный) |
| HTTP `429`, тело `{"scope": "global"}` | `rateLimitedGlobal` | «сервис перегружен» — не то же сообщение, что личный лимит |
| HTTP `503` | `aiDisabled` | «AI временно недоступен» |
| HTTP `422`, невалидный JSON, нарушение правил §3 | `invalidResponse` | заготовленная реплика персонажа в бабле, `isFallback: true` |
| `receiveTimeout` / общий таймаут 15 с | `timeout` | то же, что `invalidResponse` (FR-027b) |
| любой другой статус (`4xx`/`5xx`) | `invalidResponse` | то же |

**Логирование** (FR-034b): фиксируется только код отказа и `characterId`. Ни `dayText`, ни текст
реплики, ни тело ответа в лог не попадают — включая сообщения `DioException`, которые могут нести
тело запроса.

**Правило слоя**: HTTP-статусы видит только `AiReactionRepositoryImpl`. `TableCubit` работает
исключительно с `Result<CharacterReaction>` и подклассами `AppFailure` — сырые коды и `DioException`
до presentation не доходят (принцип I/II).

Тексты берутся из `AiProxyFailure.localizedMessage(AppLocalizations)`; UI их не собирает.

## 5. Интерфейсы

**Обновлено фазой 007** (research.md R13/R20): оба метода получили `moodScore` и `attempt`;
`AiProxyClient` дополнительно зависит от `IntegrityTokenProvider` и сам кладёт `integrityToken` в
тело — `AiReactionRepositoryImpl` о подтверждении подлинности по-прежнему не знает ничего
(принцип I).

```dart
// core/network/ai_proxy_client.dart
abstract interface class AiProxyClient {
  /// Сырой ответ прокси или проброс DioException — маппинг делает репозиторий.
  Future<AiReactionDto> react({
    required String installId,
    required String characterId,
    required String dayText,
    required int moodScore,
    required int attempt,
  });
}

// domain/repositories/ai_reaction_repository.dart
abstract interface class AiReactionRepository {
  /// Никогда не бросает: любой отказ приходит как Failure(AiProxyFailure).
  Future<Result<CharacterReaction>> requestReaction({
    required String characterId,
    required String dayText,
    required int dayEntryId,
    required int moodScore,
    required int attempt,
  });
}
```

`AiReactionRepository` живёт в `domain/repositories/`, реализация — в `data/repositories/`;
`AiReactionDto` — в `data/models/` с `@JsonSerializable` (форма ответа не меняется фазой 007).

## 6. Заглушка (`StubAiProxyClient`)

Выбирается, когда `PROXY_BASE_URL` пуст. Поведение:

- задержка 1.2 с (чтобы состояние ожидания было видно — FR-016);
- реплика собирается из `Character.name` и первых слов `dayText`, тон варьируется по персонажу —
  четыре персонажа обязаны давать четыре различающиеся между собой реплики на один и тот же текст
  (SC-003a);
- сценарий отказа задаётся статическим полем по образцу `DebugFailureInjector`: следующий вызов
  вернёт выбранный `AiProxyFailure`. Так все пять веток §4 проверяются без сети и без прокси.

Заглушка **не** используется, когда `PROXY_BASE_URL` задан, и не участвует в автотестах — там
`AiReactionRepository` подменяется `mocktail`-моком.
