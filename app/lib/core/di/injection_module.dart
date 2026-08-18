import 'package:injectable/injectable.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/app_clock/system_app_clock.dart';
import 'package:roundtablezoo/core/bootstrap/storage_mode.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/notifications/notification_scheduler.dart';
import 'package:roundtablezoo/core/notifications/reminder_coordinator.dart';
import 'package:roundtablezoo/data/datasources/character_catalog.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
import 'package:roundtablezoo/domain/services/reminder_planner.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/app_settings_cubit.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/current_day_cubit.dart';
import 'package:roundtablezoo/presentation/onboarding/cubit/onboarding_cubit.dart';
import 'package:roundtablezoo/presentation/onboarding/cubit/onboarding_state.dart';
import 'package:roundtablezoo/presentation/settings/cubit/settings_cubit.dart';
import 'package:roundtablezoo/presentation/table/cubit/table_cubit.dart';
import 'package:timezone/timezone.dart' as tz;

/// Instantiation for classes that either come from third-party packages
/// (can't carry `@injectable` themselves) or should stay framework-free
/// (`domain/`, principle I).
///
/// `AppDatabase` and everything built on top of it (datasources,
/// `DiaryRepository`, `SettingsRepository`) are deliberately **not** here —
/// which one is current depends on the runtime outcome of
/// `AppBootstrap.start()`, so `StorageDiSwitch` registers them instead
/// (`main.dart`, `RootBlocListener`).
@module
abstract class InjectionModule {
  /// `TimeZones.initialize()` must have run (sets `tz.local`) before DI is
  /// configured — see `main.dart`.
  @lazySingleton
  AppClock get appClock => SystemAppClock(initialLocation: tz.local);

  @lazySingleton
  DayResolver get dayResolver => DayResolver();

  /// No runtime dependencies — parses `assets/characters/characters.json`
  /// and caches the result for the app's lifetime (data-model.md §2). The
  /// ai-proxy client (real/stub, chosen by `AiProxyConfig.isConfigured`) is
  /// registered alongside `AiReactionRepository` once it exists
  /// (`specs/004-table-screen/tasks.md` T037/T040) — nothing here needs it
  /// yet.
  @lazySingleton
  CharacterCatalog get characterCatalog => CharacterCatalog();

  /// Screen-scoped `factory` (not `@lazySingleton`) — a fresh instance per
  /// visit to `/table`, same reasoning as [settingsCubit]. `DiaryRepository`
  /// and `StorageMode` are only resolved from `getIt` the first time this
  /// is actually built, by which point `StorageDiSwitch` has registered
  /// them (same lazy-resolution reasoning as [currentDayCubit]).
  @injectable
  TableCubit tableCubit(DiaryRepository diaryRepository, StorageMode storageMode) =>
      TableCubit(diaryRepository: diaryRepository, storageMode: storageMode);

  @lazySingleton
  ReminderPlanner reminderPlanner(DayResolver dayResolver) => ReminderPlanner(dayResolver: dayResolver);

  /// A `LazySingleton` factory, not a getter: the `SettingsRepository`
  /// parameter is only resolved from `getIt` the first time this cubit is
  /// actually built, by which point `StorageDiSwitch` has registered it
  /// (nothing reaches a screen that reads this cubit before storage is
  /// usable — the router redirects to `/storage-error` until then).
  @lazySingleton
  CurrentDayCubit currentDayCubit(
    AppClock clock,
    DayResolver dayResolver,
    SettingsRepository settingsRepository,
  ) => CurrentDayCubit(
    clock: clock,
    dayResolver: dayResolver,
    settingsRepository: settingsRepository,
  );

  /// Same lazy-resolution reasoning as [currentDayCubit] above.
  @lazySingleton
  AppSettingsCubit appSettingsCubit(SettingsRepository settingsRepository) =>
      AppSettingsCubit(settingsRepository: settingsRepository);

  /// Registered for test/uniformity purposes (research.md, R9) — the app
  /// itself uses the instance `main.dart` builds with an already-resolved
  /// initial state, not this one. A locator, not a resolved
  /// `SettingsRepository` parameter: unlike the cubits above, this one can
  /// be constructed *before* `StorageDiSwitch` has registered anything
  /// (`StorageMode.unavailable`), so resolving eagerly here would crash.
  @lazySingleton
  OnboardingCubit onboardingCubit() => OnboardingCubit(
    settingsRepositoryLocator: () => getIt<SettingsRepository>(),
    initialState: const OnboardingState.unknown(),
  );

  /// Screen-scoped `factory` (not `@lazySingleton`) — a fresh instance per
  /// visit to `/settings`, unlike the app-wide cubits above (research.md,
  /// R9; `project/process/lessons-learned.md`).
  @injectable
  SettingsCubit settingsCubit(
    SettingsRepository settingsRepository,
    NotificationScheduler notificationScheduler,
  ) => SettingsCubit(settingsRepository: settingsRepository, notificationScheduler: notificationScheduler);

  /// Same lazy-resolution reasoning as [currentDayCubit]: `SettingsRepository`
  /// and `DiaryRepository` are only resolved from `getIt` the first time
  /// this is actually built, by which point `StorageDiSwitch` has
  /// registered them.
  @lazySingleton
  ReminderCoordinator reminderCoordinator(
    AppClock clock,
    DayResolver dayResolver,
    ReminderPlanner reminderPlanner,
    NotificationScheduler notificationScheduler,
    SettingsRepository settingsRepository,
    DiaryRepository diaryRepository,
  ) => ReminderCoordinator(
    clock: clock,
    dayResolver: dayResolver,
    reminderPlanner: reminderPlanner,
    notificationScheduler: notificationScheduler,
    settingsRepository: settingsRepository,
    diaryRepository: diaryRepository,
  );
}
