import 'package:injectable/injectable.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/app_clock/system_app_clock.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/current_day_cubit.dart';
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
}
