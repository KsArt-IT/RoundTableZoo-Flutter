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

```json
{
  "installId": "32 hex-символа из user_settings.installId",
  "characterId": "hippo",
  "dayText": "Текст пользователя о своём дне"
}
```

- `integrityToken` из §4 контракта прокси **в этой фазе не отправляется** — добавляется вместе с
  прокси, который умеет его проверять.
- `dayText` уходит ровно в том виде, в каком сохранён (уже нормализован `Validators.dayText`).
- Ничего сверх этих трёх полей клиент не шлёт: `moodScore`, дневник и история реплик устройство
  не покидают (принцип V).

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

| Ситуация | Код `AiProxyFailure` | Что видит пользователь |
|---|---|---|
| `DioExceptionType.connectionError`, `connectionTimeout`, отсутствие сети | `network` | сообщение «нет сети» рядом со столом, слот возвращается в прежнее состояние |
| HTTP `429` | `rateLimited` | «лимит на сегодня» (текст отличен от сетевого) |
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

```dart
// core/network/ai_proxy_client.dart
abstract interface class AiProxyClient {
  /// Сырой ответ прокси или проброс DioException — маппинг делает репозиторий.
  Future<AiReactionDto> react({
    required String installId,
    required String characterId,
    required String dayText,
  });
}

// domain/repositories/ai_reaction_repository.dart
abstract interface class AiReactionRepository {
  /// Никогда не бросает: любой отказ приходит как Failure(AiProxyFailure).
  Future<Result<CharacterReaction>> requestReaction({
    required String characterId,
    required String dayText,
    required int dayEntryId,
  });
}
```

`AiReactionRepository` живёт в `domain/repositories/`, реализация — в `data/repositories/`;
`AiReactionDto` — в `data/models/` с `@JsonSerializable`.

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
