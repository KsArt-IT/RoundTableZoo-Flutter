# UI & Gate Contracts: Онбординг — первый запуск

Внешних API у мобильного приложения нет — контрактами этой фичи служат экран, гейт роутера и
публичная поверхность Cubit-а. Изменения существующих контрактов помечены **CHANGED**.

## 1. `OnboardingCubit` (новый)

`app/lib/presentation/onboarding/cubit/onboarding_cubit.dart`

```dart
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required SettingsRepository Function() settingsRepositoryLocator,
    required OnboardingState initialState,
    this.writeTimeout = defaultWriteTimeout,
  });

  /// Верхняя граница ожидания записи (FR-005b, SC-003). Параметр, а не
  /// константа: тест на таймаут иначе реально ждал бы 3 секунды на каждом
  /// прогоне `flutter test`.
  final Duration writeTimeout;

  static const Duration defaultWriteTimeout = Duration(seconds: 3);

  /// Разрешает `unknown`, прочитав `hasSeenOnboarding`. No-op в любом
  /// другом состоянии (research.md, R3). Вызывается из RootBlocListener,
  /// когда хранилище становится пригодным.
  ///
  /// Различает два исхода (FR-001a):
  /// - локатор бросил (репозиторий ещё не зарегистрирован) → остаёмся в
  ///   `unknown`: показывать нечего, гейт ещё не решён;
  /// - репозиторий ответил `Result.failure` → `required`: прочитать флаг не
  ///   удалось, значит трактуем как `false` и показываем онбординг.
  Future<void> resolve();

  /// Подтверждение онбординга: ждёт `markOnboardingSeen()` не дольше
  /// [writeTimeout] и переходит в `completed` независимо от исхода
  /// (FR-005, FR-005b, FR-006). No-op в `submitting`/`completed` (FR-005a).
  Future<void> complete();
}
```

**Гарантии**

| # | Гарантия | Требование |
|---|---|---|
| C1 | `complete()` не эмитит `completed` раньше, чем завершится `markOnboardingSeen()` — либо чем истечёт `writeTimeout` | FR-005, FR-005b |
| C2 | `complete()` эмитит `completed` и при `Result.failure` | FR-006 |
| C3 | Второй `complete()` во время `submitting` не вызывает репозиторий повторно | FR-005a |
| C4 | `completed` никогда не сменяется на `required` | FR-006a, FR-007 |
| C5 | `resolve()` при недоступном репозитории (локатор бросил) оставляет `unknown` и не бросает наружу | FR-006b |
| C8 | `resolve()` при `Result.failure` от зарегистрированного репозитория даёт `required`, а не `unknown` | FR-001a |
| C6 | После `close()` ни один `await`-путь не эмитит (`isClosed`-guard) | Конституция VI |
| C7 | По истечении `writeTimeout` состояние становится `completed`, даже если репозиторий не ответил | FR-005b, SC-003 |
| C9 | Прямой переход на `/onboarding` при `completed` не показывает экран (редирект, правило 4) | FR-007a |

Локатор, а не сам репозиторий, — потому что в аварийном сценарии `SettingsRepository` ещё не
зарегистрирован в момент конструирования (research.md, R3). В тестах передаётся `() => mockRepo`.

## 2. Гейт в роутере — **CHANGED**

`app/lib/app/router/app_router.dart`

```dart
GoRouter buildAppRouter({
  required StorageRecoveryCubit storageRecoveryCubit,
  required OnboardingCubit onboardingCubit,   // НОВЫЙ параметр
  required Listenable refreshListenable,      // теперь Listenable.merge двух источников
});
```

Порядок правил `redirect` (сверху вниз, первое сработавшее выигрывает):

| # | Условие | Результат | Требование |
|---|---|---|---|
| 1 | хранилище непригодно и мы не на `/storage-error` | → `/storage-error` | FR-021a/b (001), без изменений |
| 2 | хранилище пригодно и мы на `/storage-error` | → `/table` | без изменений |
| 3 | состояние гейта `required`/`submitting` и мы не на `/onboarding` | → `/onboarding` | FR-001, FR-002, FR-002b |
| 4 | состояние гейта `completed`/`unknown` и мы на `/onboarding` | → `/table` | FR-007, FR-007a |
| 5 | иначе | `null` | — |

Правило 3 намеренно идёт **после** storage-правил: при непригодном хранилище пользователь должен
видеть экран восстановления, а не онбординг. Правило 4 включает `unknown`, чтобы `/onboarding`
нельзя было открыть напрямую в состоянии, где гейт не решён.

`AppRoutes.onboardingPath` / `onboardingName` — существующие константы, не меняются; комментарий
«зарегистрирован, но без redirect-гейта» в `app_routes.dart` требует обновления.

## 3. `OnboardingPage` (новый; заменяет `OnboardingPlaceholderPage`)

`app/lib/presentation/onboarding/onboarding_page.dart`

**Состав экрана** (FR-003: один экран, одно действие):

| Элемент | Содержимое | Требование |
|---|---|---|
| Заголовок | приветствие | FR-004 |
| Пункт (a) | как пользоваться столом: отметить настроение, при желании тапнуть по персонажу | FR-004(a) |
| Пункт (b) | реплики — развлечение, не медицинский совет и не профессиональная поддержка | FR-004(b) |
| Пункт (c) | текст дня отправляется стороннему AI-сервису и не хранится на сервере | FR-004(c), конституция V |
| Кнопка | единственное действие продолжения, активна сразу | FR-003, US2 |

**Поведение**

- Нажатие → `context.read<OnboardingCubit>().complete()`. Навигацию **инициирует редирект**
  (правило 4), а не сам экран — `context.go` из виджета не вызывается.
- В `submitting` кнопка `onPressed: null`.
- Нижнего навигационного бара нет (маршрут вне шелла); собственной кнопки «назад» в `AppBar` нет;
  ссылок на другие экраны нет (FR-003a).
- Содержимое обёрнуто в прокрутку, чтобы при увеличенном системном шрифте, в ландшафте и на малых
  экранах текст не обрезался (FR-010b) — при настройках по умолчанию прокрутка не нужна: заголовок,
  все три пункта (включая (c)) и кнопка помещаются на первом экране (FR-004a, FR-004c).
- Фокус доступности при открытии — на заголовке экрана (FR-010a).

**Доступность** (FR-010, SC-004)

| Требование | Проверка |
|---|---|
| Тап-таргет кнопки ≥ `AppConstants.minTapTargetDp` (48) | `meetsGuideline(androidTapTargetGuideline)` |
| У всех тапабельных узлов есть метка | `meetsGuideline(labeledTapTargetGuideline)` |
| Весь текст доступен screen reader | текстовые виджеты без `ExcludeSemantics` |
| Нет обрезки при увеличенном шрифте | прогон при `textScaler` ×2 без `RenderFlex overflow` |

Собственный `Semantics(label:)` поверх кнопки **не** добавляется — `FilledButton` строит метку из
своего `child` (см. `project/process/lessons-learned.md`, случай с `RadioListTile`).

## 4. `AppRoot` / `main.dart` — **CHANGED**

```dart
class AppRoot extends StatelessWidget {
  const AppRoot({
    required this.storageRecoveryCubit,
    required this.onboardingCubit,     // НОВЫЙ параметр
    this.remindersMuted = false,
    super.key,
  });
}
```

- `main.dart` в ветке `StorageMode.persistent` строит начальное состояние из **уже загруженного**
  снимка настроек: `settings?.hasSeenOnboarding ?? false` → `completed` / `required`. Повторного
  чтения БД не добавляется (research.md, R2).
- В ветке `unavailable` начальное состояние — `unknown`.
- `AppRoot` провайдит cubit через `BlocProvider.value` (владелец — `main.dart`, как у
  `StorageRecoveryCubit`).

## 5. `RootBlocListener` — **CHANGED**

В обработчике `StorageRecoveryCubit`, там же где вызывается `StorageDiSwitch`:

```dart
case StorageRecoveryRecovered(:final database):
  StorageDiSwitch.usePersistentStorage(database);
  unawaited(context.read<OnboardingCubit>().resolve());   // НОВОЕ
case StorageRecoveryReadOnlyAccepted():
  StorageDiSwitch.useReadOnlyStorage();
  unawaited(context.read<OnboardingCubit>().resolve());   // НОВОЕ
```

Порядок обязателен: `resolve()` читает `SettingsRepository`, который регистрирует `StorageDiSwitch`
строкой выше.

## 6. `test/support/test_app_root.dart` — **CHANGED** (контракт тестового хелпера)

```dart
Widget buildTestAppRoot({
  StorageRecoveryState? initialState,
  bool remindersMuted = false,
  bool onboardingSeen = true,   // НОВЫЙ — по умолчанию онбординг пройден
});
```

`onboardingSeen: true` по умолчанию — существующие widget-тесты шелла не должны знать про
онбординг; свежая in-memory БД иначе увела бы их все на `/onboarding` (research.md, R7). На каждый
вызов создаётся свежий `OnboardingCubit` — тем же приёмом `unregister` + `registerLazySingleton`,
что уже применяется к `AppSettingsCubit`.

## 7. Ключи локализации (новые)

`lib/l10n/intl_ru.arb` (template) + `intl_en.arb` + `intl_uk.arb`, все три обязательны:

| Ключ | Назначение |
|---|---|
| `onboardingTitle` | заголовок экрана |
| `onboardingHowTo` | пункт (a) — FR-004(a) |
| `onboardingDisclaimer` | пункт (b) — FR-004(b) |
| `onboardingAiDisclosure` | пункт (c) — FR-004(c) |
| `onboardingStart` | метка кнопки продолжения |

Существующий ключ `sectionOnboarding` использовался только заглушкой; после замены страницы он
остаётся невостребованным — удалить из всех трёх `.arb`, если больше нигде не используется.

Метода репозитория фича не добавляет — `contracts/repositories.md` фичи 001/002 остаётся в силе
без изменений.
