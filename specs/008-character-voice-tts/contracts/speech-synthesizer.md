# Contract: `SpeechSynthesizer` и `SilentModeProbe`

Два сервиса в `core/speech/`. Оба — абстракции с платформенной реализацией, оба подменяются
моками в тестах (`test/support/test_app_root.dart`), по образцу `NotificationScheduler`
(`specs/002-settings-and-reminders/contracts/notifications.md`).

---

## 1. `SpeechSynthesizer`

```dart
abstract interface class SpeechSynthesizer {
  /// Инициализация движка. Идемпотентна. Выставляет awaitSpeakCompletion(true)
  /// и iOS-категорию аудио (research.md R4, R6).
  Future<Result<void>> initialize();

  /// Есть ли на устройстве локальный голос для [languageTag] («ru», «ru-RU»).
  /// Android — isLanguageInstalled (исключает сетевые голоса, research.md R3),
  /// iOS — isLanguageAvailable. Движок недоступен → success(false), не failure.
  Future<Result<bool>> isAvailableFor(String languageTag);

  /// Произносит [request] целиком. Future завершается ПО ОКОНЧАНИИ
  /// произнесения (awaitSpeakCompletion), а не по факту отправки команды.
  /// Прерванное [stop]-ом произнесение завершает future так же успешно —
  /// вызывающая сторона отличает это по собственному состоянию, не по Result.
  Future<Result<void>> speak(SpeechRequest request);

  /// Немедленно останавливает текущее произнесение. Безопасен, когда ничего
  /// не звучит.
  Future<Result<void>> stop();
}

/// Одна команда синтеза. Всё, что нужно применить перед speak.
class SpeechRequest {
  final String text;
  final String languageTag;
  final CharacterVoice voice;
}
```

### Поведенческие требования

| # | Требование | Из |
|---|---|---|
| S1 | `initialize` вызывает `awaitSpeakCompletion(true)`; `setQueueMode` не трогается (на Android ожидание завершения работает только при `QUEUE_FLUSH`) | research.md R4 |
| S2 | На iOS `initialize` выставляет категорию `ambient` с опциями `mixWithOthers` + `duckOthers` | FR-011a, FR-011b, research.md R6 |
| S3 | `speak` перед произнесением применяет `setLanguage(languageTag)`, `setPitch(voice.pitch)`, `setSpeechRate(voice.rate)` — в этом порядке, на каждую реплику (тембр меняется от персонажа к персонажу) | FR-003 |
| S4 | На Android `speak` вызывается с `focus: true` — плагин запрашивает `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` и отпускает фокус по завершении | FR-011a |
| S5 | Любое исключение платформы (`MissingPluginException`, `PlatformException`, что угодно) превращается в `Result.failure` через `SafeCallMixin` и **не** пробрасывается наружу | FR-012, принцип II |
| S6 | `isAvailableFor` при недоступном движке возвращает `success(false)`, а не failure — «движка нет» это не сбой, а состояние устройства | FR-012 |
| S7 | Сервис не хранит очередь, не знает о персонажах и не решает, можно ли говорить — только выполняет команду | принцип I |

### Регистрация

`@LazySingleton(as: SpeechSynthesizer)` для `FlutterTtsSpeechSynthesizer` — один экземпляр движка
на процесс. `initialize()` вызывается лениво, при первом обращении, а не в `main.dart`: экран
может ни разу не понадобиться, а инициализация движка не бесплатна.

---

## 2. `SilentModeProbe`

```dart
abstract interface class SilentModeProbe {
  /// true — устройство сейчас «молчит» и озвучка звучать не должна.
  Future<bool> isSilent();
}
```

| Реализация | Платформа | Поведение |
|---|---|---|
| `AndroidSilentModeProbe` | Android | `MethodChannel('life.studyway.roundtablezoo/audio').invokeMethod<bool>('isSilent')`; ошибка канала → `false` (лучше сказать вслух, чем потерять фичу из-за сбоя пробы) |
| `NoSilentModeProbe` | всё остальное | всегда `false` — на iOS «без звука» обеспечивает категория `ambient` (S2), отдельная проба не нужна |

Выбор реализации — в `InjectionModule` по `defaultTargetPlatform`, тем же приёмом, что уже
используется для `IntegrityTokenProvider`.

### Kotlin-сторона (`AudioModeChannel.kt`)

| Метод | Возврат | Логика |
|---|---|---|
| `isSilent` | `Boolean` | `audioManager.ringerMode != AudioManager.RINGER_MODE_NORMAL || audioManager.getStreamVolume(AudioManager.STREAM_MUSIC) == 0` |

Регистрируется в `MainActivity.configureFlutterEngine` рядом с `IntegrityChannel`. Разрешений не
требует.
