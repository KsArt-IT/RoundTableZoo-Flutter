import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/integrity/integrity_token_provider.dart';
import 'package:roundtablezoo/core/network/ai_proxy_client.dart';
import 'package:roundtablezoo/core/notifications/notification_scheduler.dart';
import 'package:roundtablezoo/core/sharing/share_service.dart';
import 'package:roundtablezoo/core/speech/silent_mode_probe.dart';
import 'package:roundtablezoo/core/speech/speech_synthesizer.dart';
import 'package:roundtablezoo/data/datasources/character_catalog.dart';
import 'package:roundtablezoo/domain/repositories/ai_reaction_repository.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/usecases/export_diary_to_csv.dart';

/// Shared mocktail doubles for tests.
class MockAppClock extends Mock implements AppClock {}

class MockDiaryRepository extends Mock implements DiaryRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockNotificationScheduler extends Mock implements NotificationScheduler {}

class MockSpeechSynthesizer extends Mock implements SpeechSynthesizer {}

class MockSilentModeProbe extends Mock implements SilentModeProbe {}

/// `CharacterCatalog` isn't behind an interface (data-model.md §2 — no
/// runtime dependencies, plain class), so this subclasses it directly
/// rather than `implements`, same as any other mocktail double over a
/// concrete class with no injected state.
class MockCharacterCatalog extends Mock implements CharacterCatalog {}

class MockAiReactionRepository extends Mock implements AiReactionRepository {}

class MockAiProxyClient extends Mock implements AiProxyClient {}

class MockIntegrityTokenProvider extends Mock implements IntegrityTokenProvider {}

class MockShareService extends Mock implements ShareService {}

/// `ExportDiaryToCsv` isn't behind an interface (it's a single-method
/// usecase, same reasoning as `CharacterCatalog`), so this subclasses it
/// directly rather than `implements` an abstraction.
class MockExportDiaryToCsv extends Mock implements ExportDiaryToCsv {}
