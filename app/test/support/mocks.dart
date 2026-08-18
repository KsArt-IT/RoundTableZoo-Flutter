import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/network/ai_proxy_client.dart';
import 'package:roundtablezoo/core/notifications/notification_scheduler.dart';
import 'package:roundtablezoo/data/datasources/character_catalog.dart';
import 'package:roundtablezoo/domain/repositories/ai_reaction_repository.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';

/// Shared mocktail doubles for tests.
class MockAppClock extends Mock implements AppClock {}

class MockDiaryRepository extends Mock implements DiaryRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockNotificationScheduler extends Mock implements NotificationScheduler {}

/// `CharacterCatalog` isn't behind an interface (data-model.md §2 — no
/// runtime dependencies, plain class), so this subclasses it directly
/// rather than `implements`, same as any other mocktail double over a
/// concrete class with no injected state.
class MockCharacterCatalog extends Mock implements CharacterCatalog {}

class MockAiReactionRepository extends Mock implements AiReactionRepository {}

class MockAiProxyClient extends Mock implements AiProxyClient {}

// MockShareService is added once its interface exists
// (`core/sharing/share_service.dart` — tasks.md T070/US5).
