# Contract — `IntegrityTokenProvider` (клиент)

**Feature**: `specs/007-ai-proxy` | **Решения**: research.md R3, R4, R13, R14

Единственная точка приложения, знающая про подтверждение подлинности. Живёт в
`core/integrity/`, потому что это платформенный механизм, а не бизнес-правило: ни `domain/`, ни
`data/` о нём не знают (принцип I).

## 1. Интерфейс

```dart
abstract interface class IntegrityTokenProvider {
  Future<String?> token();
  void invalidate();
}
```

| Метод | Контракт |
|---|---|
| `token()` | Возвращает кэшированный токен; при пустом кэше — запрашивает у платформы и кэширует на весь процесс. Никогда не бросает: любой сбой платформы → `null`. Одновременные вызовы при пустом кэше дают **один** запрос к платформе. |
| `invalidate()` | Очищает кэш. Идемпотентен. Следующий `token()` запросит свежий. |

`null` означает «подтверждения не будет» — вызывающая сторона отправляет запрос без него, а не
отменяет запрос: решение о том, допустимо ли это, принимает служба (R14).

## 2. Реализации

| Класс | Условие выбора в DI | Поведение |
|---|---|---|
| `PlayIntegrityTokenProvider` | `defaultTargetPlatform == TargetPlatform.android` | `MethodChannel('life.studyway.roundtablezoo/integrity').invokeMethod<String>('requestToken')` |
| `UnsupportedIntegrityTokenProvider` | остальные платформы | `token()` → `null`, `invalidate()` → no-op |

Тесты подменяют провайдер `mocktail`-моком; настоящий `MethodChannel` в автотестах не вызывается.

## 3. Использование в `DioAiProxyClient` (R13)

```
react(...):
  token ← provider.token()
  ответ ← POST /react { installId, characterId, dayText, integrityToken?: token }
  если ответ == 403 и попытка первая:
      provider.invalidate()
      token ← provider.token()
      ответ ← POST /react { … }        // ровно один повтор, FR-010a
  вернуть ответ или пробросить DioException
```

- Повтор — **ровно один**. Второй `403` пробрасывается наверх и превращается в
  `AiProxyFailure(integrityRejected)`.
- Повтор выполняется только на `403`. Ни `429`, ни `503`, ни `422`, ни сетевые ошибки не
  повторяются: повтор инициирует пользователь тапом (`ai-proxy-client.md` §1).
- Общий бюджет `AppConstants.aiRequestTimeout` (15 с) оборачивает **обе** попытки вместе, а не
  каждую по отдельности, — иначе максимальное ожидание удваивается и SC-002 не выполняется.

## 4. Android-сторона канала

```
метод: "requestToken"
успех:  String  — токен
ошибка: PlatformException(code, message) — на стороне Dart превращается в null
```

Токен запрашивается Standard-запросом Play Integrity; подготовка провайдера токенов выполняется
лениво при первом обращении и переиспользуется (research.md R4). Ни `installId`, ни `dayText` в
канал не передаются — каналу нечего знать о содержании запроса.
