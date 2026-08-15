import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';

/// Shared mocktail doubles for tests.
class MockAppClock extends Mock implements AppClock {}

class MockDiaryRepository extends Mock implements DiaryRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}
