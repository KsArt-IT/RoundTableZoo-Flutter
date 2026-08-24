import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';

/// Requests one character's reply to the day's text
/// (`specs/004-table-screen/contracts/ai-proxy-client.md` §5). The
/// anonymous install identifier never crosses this boundary — the
/// implementation reads it itself, so `TableCubit` never needs to know it
/// exists.
abstract interface class AiReactionRepository {
  /// Never throws: any failure — network, HTTP, malformed response — comes
  /// back as `Result.failure(AiProxyFailure)`.
  Future<Result<CharacterReaction>> requestReaction({
    required String characterId,
    required String dayText,
    required int dayEntryId,
    required int moodScore,
    required int attempt,
  });
}
