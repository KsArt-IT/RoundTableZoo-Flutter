import 'package:injectable/injectable.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/app_clock/system_app_clock.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
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
}
