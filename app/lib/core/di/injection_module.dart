import 'package:injectable/injectable.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/app_clock/system_app_clock.dart';
import 'package:roundtablezoo/core/bootstrap/storage_mode.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/network/ai_proxy_client.dart';
import 'package:roundtablezoo/core/network/ai_proxy_config.dart';
import 'package:roundtablezoo/core/network/stub_ai_proxy_client.dart';
import 'package:roundtablezoo/core/notifications/notification_scheduler.dart';
import 'package:roundtablezoo/core/notifications/reminder_coordinator.dart';
import 'package:roundtablezoo/core/sharing/share_service.dart';
import 'package:roundtablezoo/data/datasources/character_catalog.dart';
import 'package:roundtablezoo/data/repositories/ai_reaction_repository_impl.dart';
import 'package:roundtablezoo/domain/repositories/ai_reaction_repository.dart';
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
  /// and caches the result for the app's lifetime (data-model.md §2).
  @lazySingleton
  CharacterCatalog get characterCatalog => CharacterCatalog();

  /// Real client when a proxy address is configured, the deterministic
  /// stub otherwise (research.md R2, R14) — never both, never chosen by
  /// anything downstream.
  @lazySingleton
  AiProxyClient get aiProxyClient =>
      AiProxyConfig.isConfigured ? DioAiProxyClient() : StubAiProxyClient();

  /// `SettingsRepository` is only resolved from `getIt` the first time this
  /// is actually built, by which point `StorageDiSwitch` has registered it
  /// (same lazy-resolution reasoning as [currentDayCubit]).
  @lazySingleton
  AiReactionRepository aiReactionRepository(
    AiProxyClient aiProxyClient,
    SettingsRepository settingsRepository,
    AppClock clock,
  ) => AiReactionRepositoryImpl(
    client: aiProxyClient,
    settingsRepository: settingsRepository,
    clock: clock,
  );

  /// Screen-scoped `factory` (not `@lazySingleton`) — a fresh instance per
  /// visit to `/table`, same reasoning as [settingsCubit]. `DiaryRepository`,
  /// `SettingsRepository` and `StorageMode` are only resolved from `getIt`
  /// the first time this is actually built, by which point `StorageDiSwitch`
  /// has registered them (same lazy-resolution reasoning as [currentDayCubit]).
  @injectable
  TableCubit tableCubit(
    DiaryRepository diaryRepository,
    SettingsRepository settingsRepository,
    AiReactionRepository aiReactionRepository,
    CharacterCatalog characterCatalog,
    AppClock clock,
    StorageMode storageMode,
  ) => TableCubit(
    diaryRepository: diaryRepository,
    settingsRepository: settingsRepository,
    aiReactionRepository: aiReactionRepository,
    characterCatalog: characterCatalog,
    clock: clock,
    storageMode: storageMode,
  );

  @lazySingleton
  ReminderPlanner reminderPlanner(DayResolver dayResolver) =>
      ReminderPlanner(dayResolver: dayResolver);

  /// Stateless wrapper over `share_plus` — no runtime dependencies
  /// (research.md R3).
  @lazySingleton
  ShareService get shareService => const SharePlusShareService();

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
  ) => SettingsCubit(
    settingsRepository: settingsRepository,
    notificationScheduler: notificationScheduler,
  );

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
