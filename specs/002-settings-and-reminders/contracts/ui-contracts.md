# Контракт: экран настроек

Дополняет `specs/001-app-foundation/contracts/ui-contracts.md`. Маршруты не добавляются:
`/settings` уже объявлен, меняется только его `builder`.

---

## Маршрут

| Путь | Было | Стало |
|---|---|---|
| `/settings` | `SettingsPlaceholderPage` | `SettingsPage` |

`/table` остаётся `initialLocation` — это же и есть цель deep-link по тапу (FR-017,
contracts/notifications.md, R6).

---

## `SettingsCubit` (`presentation/settings/cubit/`)

Экранный, `@injectable` (factory), предоставляется маршрутом. **Не** глобальный — см.
research.md, R9.

```dart
SettingsState.loading()
SettingsState.loaded({
  required UserSettings settings,
  required NotificationPermissionStatus permission,
})
SettingsState.error({required AppFailure failure})
```

Freezed sealed, side-effects только в `listener` (принцип II).

**Вход**: `SettingsRepository.watch()` + `NotificationScheduler.permissionStatus()`.

**Значение `permission` до того, как сервис уведомлений появится** (фазы Foundational, US1, US2):
`NotificationPermissionStatus.unknown`. Секция напоминания в этих фазах ещё не отрисована, поэтому
значение ни на что не влияет, но поле обязано быть заполнено — `null` в состоянии не допускается.

**Методы**

| Метод | Требование | Поведение |
|---|---|---|
| `setThemeMode(ThemePreference)` | FR-005…FR-007 | `updateThemeMode` → `watch()` эмитит → перерисовка всего приложения |
| `setLocale(LocalePreference)` | FR-008…FR-011 | `updateLocale` |
| `setSoundEnabled({required bool value})` | FR-026 | `updateSoundEnabled` |
| `setReminderTime(ReminderTime)` | FR-013 | `updateReminderTime` |
| `setReminderEnabled({required bool value})` | FR-012, FR-020, FR-020a | При включении сразу `requestPermission()` — без собственного диалога-предисловия; статус попадает в состояние; настройка сохраняется **в любом случае** (см. ниже). При статусе `denied` системный запрос не повторяется — сразу показывается предупреждение с переходом в настройки (FR-022a) |
| `openNotificationSettings()` | FR-021, FR-025b | `NotificationScheduler.openSystemSettings()` |
| `refreshPermissionStatus()` | FR-022 | Перечитывает статус; зовётся экраном на `resumed` |

**Почему настройка сохраняется даже при отказе в разрешении**: намерение пользователя («хочу
напоминание») и техническая возможность — разные вещи. Сохранив тумблер включённым и показав
предупреждение, приложение отправит напоминания сразу, как только разрешение появится, без
повторного включения — ровно то, что требует FR-022. Сброс тумблера обратно потерял бы намерение.

**Откат при ошибке сохранения (FR-003)** не требует кода: UI рисуется по `UserSettings` из
`watch()`. Неудачный `update*` не меняет строку → `watch()` молчит → элемент остаётся в прежнем
положении. Ошибка уходит тостом (`AppFailure`, `RootBlocListener`).

**Обязательные тесты** (`test/presentation/settings/settings_cubit_test.dart`, покрытие >70%):
успех каждого сеттера; ошибка репозитория по каждому коду `AppFailure`; включение при
`granted` / `denied`; `refreshPermissionStatus` после возврата из системных настроек; `isClosed`
после `await`.

---

## `SettingsPage`

`StatefulWidget` с `WidgetsBindingObserver` — на `AppLifecycleState.resumed` зовёт
`refreshPermissionStatus()` (FR-022). Обсервер экранный: за пределами настроек статус разрешения
никого не интересует.

**Секции** (в порядке сверху вниз)

| Секция | Содержимое | Требования |
|---|---|---|
| Оформление | Тема: светлая / тёмная / системная | FR-005…FR-007 |
| Язык | Русский / Українська / English / системный — **каждое название на своём языке** | FR-008…FR-011 |
| Напоминание | Тумблер + выбор времени (активен только при включённом, формат 12/24 ч по локали) + предупреждение о разрешении | FR-012, FR-013, FR-013a, FR-021 |
| Звук | Тумблер озвучки реплик. Подпись MUST давать понять, что уведомлений он не касается | FR-016c, FR-026 |

Тумблеров видимости персонажей здесь нет (Clarifications, Q1).

**Состояния экрана**

- `loading` — все секции в окончательной разметке с недоступными элементами управления. Переход в
  `loaded` не меняет положение и размер ни одного элемента (FR-004).
- `error` — экран остаётся пригодным к использованию, ошибка приходит тостом; пустого экрана не
  показывается.

---

## Разовый тост при запуске (FR-021b)

Отдельная поверхность, **не** проходящая через `RootBlocListener` и `FailureToastGate`: это не
ошибка, а уведомление о последствии, а гейт схлопывает повторы в окне 3 секунд, а не на запуск.

```dart
// main.dart, до runApp — статус уже известен, хранилище признано пригодным
final remindersMuted = settings.reminderEnabled &&
    await scheduler.permissionStatus() != NotificationPermissionStatus.granted;

runApp(AppRoot(storageRecoveryCubit: ..., remindersMuted: remindersMuted));
```

`AppRoot` показывает тост один раз в `addPostFrameCallback` после первого кадра, внутри
маршрутизированного дерева (иначе недоступны `AppLocalizations` и `ToastificationWrapper`).

**Почему так, а не подклассом `AppFailure`**: (1) семантически это не сбой — пользователь сам
отозвал разрешение; (2) источником состояния для `RootBlocListener` пришлось бы сделать новый
глобальный Cubit, а это ровно та комбинация, которая ломает widget-тесты
(`project/process/lessons-learned.md`); (3) «один раз за запуск» здесь гарантировано конструкцией —
флаг вычисляется единожды и живёт в неизменяемом поле виджета, отдельного состояния хранить не
нужно.

**Тест**: widget-тест на `AppRoot` с `remindersMuted: true` — тост показан ровно один раз и не
появляется повторно после `pump()` и смены раздела.

---

**Предупреждение о разрешении** (`permission == denied`, FR-021):

- Текст: уведомления не придут, пока разрешение не выдано в системных настройках.
- Действие: «Открыть настройки» → `openNotificationSettings()`.
- Показывается только при `denied` и только когда `reminderEnabled == true` — при выключенном
  напоминании разрешение ничего не решает и предупреждение было бы шумом.

**Доступность (FR-027, FR-028)**

- Каждый интерактивный элемент — не меньше `AppConstants.minTapTargetDp` (48).
- `Semantics(label:)` с текущим значением: не «Тема», а «Тема: тёмная» (FR-028a).
- Выбранный вариант и положение тумблера кодируются не только цветом — отметкой/иконкой.
- Выбор времени озвучивается как время, а не как набор цифр (FR-028a).
- При системном увеличении шрифта текст не обрезается и элементы управления остаются доступны
  (FR-027a).

---

## Строки локализации (все три `.arb`)

| Ключ | Назначение |
|---|---|
| `settingsAppearance`, `settingsThemeLight`, `settingsThemeDark`, `settingsThemeSystem` | Секция темы |
| `settingsLanguage`, `settingsLanguageSystem` | Секция языка (названия языков — константы, не переводятся) |
| `settingsReminder`, `settingsReminderEnabled`, `settingsReminderTime` | Секция напоминания |
| `settingsReminderPermissionDenied`, `settingsOpenSystemSettings` | Предупреждение о разрешении |
| `reminderPermissionRevokedToast` | Разовый тост при запуске (FR-021b) |
| `settingsSound`, `settingsSoundHint` | Секция звука; подсказка о том, что уведомлений настройка не касается (FR-016c) |
| `reminderNotificationTitle`, `reminderNotificationBody` | Текст уведомления — **нейтральный** (FR-016a) |
| `notificationChannelName`, `notificationChannelDescription` | Канал уведомлений — виден в системных настройках, те же стоп-слова (FR-016b) |

`intl_ru.arb` — шаблон (`l10n.yaml`), поэтому ключ добавляется туда первым. Незаполненные
переводы попадают в `lib/gen/untranslated_messages.json` — файл обязан остаться пустым.
