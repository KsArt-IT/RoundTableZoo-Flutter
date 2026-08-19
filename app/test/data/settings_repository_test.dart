import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/data/datasources/settings_local_datasource.dart';
import 'package:roundtablezoo/data/repositories/settings_repository_impl.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';

import '../support/test_database.dart';

void main() {
  late AppDatabase db;
  late SettingsRepositoryImpl repository;

  setUp(() async {
    db = await openTestDatabase();
    repository = SettingsRepositoryImpl(dataSource: SettingsLocalDataSource(db));
  });

  tearDown(() => db.close());

  test('installId stays the same across repeated load() calls', () async {
    final first = await repository.load();
    final second = await repository.load();

    expect(first.isSuccess, isTrue);
    expect(first.valueOrNull?.installId, second.valueOrNull?.installId);
  });

  test('updateThemeMode returns the full resulting settings state', () async {
    final result = await repository.updateThemeMode(ThemePreference.dark);

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull?.themeMode, ThemePreference.dark);
    // The rest of the state is still present, not dropped.
    expect(result.valueOrNull?.installId, isNotEmpty);
  });

  test('updateDayStartHour returns the full resulting settings state', () async {
    final value = DayStartHour.create(6).valueOrGet(() => throw StateError('bad fixture'));
    final result = await repository.updateDayStartHour(value);

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull?.dayStartHour.value, 6);
  });

  test('watch() emits an updated state after a change', () async {
    final emissions = <String>[];
    final subscription = repository.watch().listen(
      (settings) => emissions.add(settings.themeMode.name),
    );

    await pumpEventQueue();
    await repository.updateThemeMode(ThemePreference.dark);
    await pumpEventQueue();

    await subscription.cancel();
    expect(emissions, contains('dark'));
  });
}
