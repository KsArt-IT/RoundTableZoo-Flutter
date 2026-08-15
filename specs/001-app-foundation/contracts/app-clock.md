# Контракт: время и вычисление дня

Принцип IV конституции: единственный `DateTime.now()` во всей кодовой базе живёт внутри
`SystemAppClock`. `domain/`, `data/` и Cubit получают время только отсюда.

## `AppClock` — `core/app_clock/app_clock.dart`

```dart
abstract interface class AppClock {
  /// Текущий момент в UTC. Единственный источник «сейчас» для всей логики.
  DateTime nowUtc();

  /// Текущая локация устройства (пакет `timezone`). Меняется при смене пояса.
  tz.Location get location;

  /// Тик раз в минуту, выровненный на начало минуты. Значение тика — момент
  /// в UTC; потребитель обязан использовать именно его, а не запрашивать
  /// время заново.
  Stream<DateTime> get minuteTicks;

  /// Переустановить локацию (вызывается на resume, если системный пояс сменился).
  void updateLocation(tz.Location location);
}
```

**Реализации**

| Реализация | Где | Поведение |
|---|---|---|
| `SystemAppClock` | `core/app_clock/system_app_clock.dart` | `DateTime.now().toUtc()`, `Timer.periodic`, локация из `FlutterTimezone` |
| `FakeAppClock` | `test/support/fake_app_clock.dart` | `set now`, `set location`, `emitTick(DateTime)` — ни таймеров, ни реальных часов |

**Инварианты**

- `nowUtc().isUtc == true` всегда.
- Поток `minuteTicks` — broadcast; `SystemAppClock.dispose()` отменяет таймер и закрывает контроллер
  (линтер `close_sinks` — error).
- Тик никогда не «догоняет» пропущенные минуты после сна устройства: потребитель обязан быть
  устойчив к разрыву (проверяет ключ дня, а не количество тиков).

## `DayResolver` — `domain/services/day_resolver.dart`

Чистая логика, без Flutter и без состояния.

```dart
class DayResolver {
  /// Какому дню принадлежит момент.
  DayKey resolve(DateTime instantUtc, {required tz.Location zone, required int dayStartHour});

  /// Границы дня как полуинтервал [start, end) в UTC — для запросов к БД.
  ({DateTime startUtc, DateTime endUtc}) boundsUtc(
    DayKey key, {required tz.Location zone, required int dayStartHour});
}
```

**Алгоритм `resolve`**: `tz.TZDateTime.from(instantUtc, zone)` → вычесть `dayStartHour` часов →
взять `(year, month, day)`.

**Алгоритм `boundsUtc`**: `start = TZDateTime(zone, key.year, key.month, key.day, dayStartHour)`,
`end = start + 24 часа`, оба переводятся в UTC. При DST-переходе сутки короче/длиннее 24 часов —
границы берутся через `TZDateTime`, не арифметикой по UTC.

**Контрактные требования (проверяются тестами)**

| Условие | Ожидаемое |
|---|---|
| `dayStartHour = 0`, момент 23:59 локально | день = текущая календарная дата |
| `dayStartHour = 0`, момент 00:00 локально | день = следующая календарная дата (FR-023, US4.1) |
| `dayStartHour = 4`, момент 02:00 локально | день = **предыдущая** календарная дата (US4.2) |
| `dayStartHour = 4`, момент 04:00 локально | день = текущая календарная дата |
| Один и тот же `instantUtc`, разные `zone` | дни могут отличаться; `instantUtc` не меняется (FR-026) |
| DST «весна вперёд»/«осень назад» | `boundsUtc` даёт непрерывное покрытие суток без дыр и наложений |
| Любой вход | результат зависит только от аргументов, не от системных часов (FR-024, SC-007) |

## `CurrentDayCubit` — `presentation/app_settings/`

Держит текущий `DayKey` и пересчитывает его.

```
Состояния: CurrentDayState.initial | .day(DayKey key)
Вход:      minuteTicks, AppLifecycleState.resumed, смена dayStartHour, смена локации
Выход:     новое состояние только при фактической смене DayKey
```

Правила: значение берётся из момента, пришедшего в тик; после `await` — `if (isClosed) return`;
эмиссия при неизменном ключе подавляется (иначе оболочка перерисовывается раз в минуту без нужды).

## Что запрещено

- `DateTime.now()` в `domain/`, `data/`, `presentation/` — включая тесты, где вместо него
  `FakeAppClock`.
- Хранить вычисленный день в БД или передавать его между слоями вместо `occurredAt`.
- Определять день арифметикой по UTC-смещению в минутах — ломается на DST (см. research R3).
