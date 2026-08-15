import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';

/// Shared mocktail doubles for tests.
///
/// Repository mocks (`DiaryRepository`, `SettingsRepository`) join this file
/// once those interfaces land (Phase 4, T040) — mocking them ahead of the
/// contracts they mock would just be dead code.
class MockAppClock extends Mock implements AppClock {}
