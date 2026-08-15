# Контракт: маршруты, состояния и поверхность ошибок

## Маршруты (`app/router/app_routes.dart`)

| Путь | Имя | Где | Заметки |
|---|---|---|---|
| `/table` | `table` | Ветка 1 оболочки | Стартовый маршрут (FR-002) |
| `/diary` | `diary` | Ветка 2 оболочки | |
| `/settings` | `settings` | Ветка 3 оболочки | |
| `/onboarding` | `onboarding` | Вне оболочки | Объявлен, **без** redirect-гарда (FR-006) |
| `/storage-error` | `storageError` | Вне оболочки, полноэкранный | Редирект сюда только при `StorageMode.unavailable` (FR-021b) |

Оболочка — `StatefulShellRoute.indexedStack` с тремя ветками: состояние ветки сохраняется,
переключение не перестраивает дерево приложения (FR-004, SC-002). Последний открытый раздел не
персистится: после выгрузки процесса — `/table` (FR-004a).

**Системная кнопка «Назад»** на корневом маршруте ветки сворачивает приложение (поведение
`PopScope` по умолчанию), белый экран не показывается (US1.4).

## Состояния Cubit

Все — Freezed sealed, side-effects только в `listener` (принцип II).

### `AppSettingsCubit` (глобальный, регистрируется в `AppRoot`)

```
AppSettingsState.initial()
AppSettingsState.loaded(UserSettings settings)
AppSettingsState.error(AppFailure failure)
```

Подписан на `SettingsRepository.watch()`. Отдаёт `themeMode` и `locale` в `MaterialApp.router`
(FR-027). Ошибка загрузки не оставляет приложение без интерфейса: применяются системная тема и
русский язык, ошибка уходит тостом.

### `CurrentDayCubit` (глобальный)

```
CurrentDayState.initial()
CurrentDayState.day(DayKey key)
```

См. [app-clock.md](./app-clock.md). Эмиссия только при фактической смене `DayKey`.

### `StorageRecoveryCubit` (`presentation/storage_recovery/`)

```
StorageRecoveryState.idle(AppFailure cause)
StorageRecoveryState.working()          // идёт сброс или повторная попытка
StorageRecoveryState.recovered()        // хранилище открылось → уходим в оболочку
StorageRecoveryState.readOnlyAccepted() // пользователь выбрал «без сохранения»
StorageRecoveryState.error(AppFailure failure)
```

Действия: `retry()`, `resetData()` (только после подтверждения в диалоге — FR-021c),
`continueWithoutSaving()`.

Переходы:

- Сбой `resetData()` → `error(failure)` **на том же экране**; `retry()` и
  `continueWithoutSaving()` остаются доступны (FR-021c1). Автоповтора сброса нет.
- Успешный `retry()` из режима без сохранения → `recovered()`: DI подменяет read-only реализации
  обратно на обычные, баннер снимается, данные доступны в том же сеансе (FR-021e1).
- `readOnlyAccepted()` живёт только в памяти сеанса — нигде не сохраняется, при следующем запуске
  `AppBootstrap.start()` выполняется как обычно (FR-021d1).

Экран рисуется **до** того, как настройки прочитаны, поэтому берёт системную тему
(`ThemeMode.system`) и системный язык, а при неподдерживаемом языке — русский (FR-021b1, FR-029).
`AppSettingsCubit` в этот момент находится в состоянии `initial`, и `AppMaterialRouter` обязан
трактовать его как «системные значения», а не как отсутствие оформления.

## Поверхность ошибок

`app/root_bloc_listener.dart` — единственная точка показа сообщений (FR-021). Слушает глобальные
Cubit, на `*State.error(failure)` вызывает `FailureToastGate.shouldShow(failure)` и при `true`
показывает тост `toastification` с `failure.localizedMessage(AppLocalizations.of(context))`.

### `FailureToastGate` — `core/errors/failure_toast_gate.dart`

```dart
class FailureToastGate {
  FailureToastGate(this._clock);
  bool shouldShow(AppFailure failure);
}
```

Ключ дедупликации — `(runtimeType, code)`. Правило: одинаковый ключ в пределах
`AppConstants.duplicateFailureWindow` (3 с, время — из `AppClock`) → `false`; другой ключ →
`true` немедленно, ключ становится последним (FR-021f, SC-014).

**Исключение из тостов**: экран `/storage-error` показывает причину сам, на своей поверхности —
дублирующий тост поверх него не показывается.

## Оболочка и доступность

| Элемент | Требование |
|---|---|
| Пункты `NavigationBar` | тап-таргет ≥ `AppConstants.minTapTargetDp` (48), `Semantics(label:)` с названием раздела (FR-030, SC-010) |
| Кнопки на `/storage-error` | те же правила; «Сбросить данные» — деструктивное оформление + диалог подтверждения |
| Баннер режима «без сохранения» | постоянный, виден на всех трёх вкладках, содержит пояснение «данные недоступны, но не удалены» и кнопку «Повторить» (FR-021d, FR-021e) |
| Заглушки разделов | центрированное название раздела из l10n; ни `Placeholder()`, ни технических строк |

## Локализация

- Шаблонный ARB — `intl_ru.arb` (`l10n.yaml`), поэтому отсутствующий перевод падает на русский
  (FR-029).
- `supportedLocales: [ru, uk, en]`; `localeResolutionCallback` → `ru` для неподдерживаемого языка
  устройства (US5.3).
- Новые строки этой фазы: названия трёх разделов, тексты экрана восстановления (заголовок,
  причина, три кнопки, текст подтверждения), баннер режима без сохранения, сообщения для новых
  кодов `DatabaseFailure` и `ValidationFailure`.
