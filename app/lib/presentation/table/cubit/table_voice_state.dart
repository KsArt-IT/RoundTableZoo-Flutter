import 'package:freezed_annotation/freezed_annotation.dart';

part 'table_voice_state.freezed.dart';

/// `TableVoiceCubit`'s state (`data-model.md` §5). A single shape, not a
/// sealed `initial/loading/loaded/error` hierarchy — voicing has neither
/// loading nor a user-facing error: a synthesis failure (FR-012) is
/// indistinguishable from "nothing to say".
@freezed
abstract class TableVoiceState with _$TableVoiceState {
  const factory TableVoiceState({
    /// Who is speaking right now; `null` means silence. The only thing the
    /// UI reads (FR-016).
    String? speakingCharacterId,

    /// Length of the waiting queue — needed by tests/debugging only, the
    /// UI never shows it.
    @Default(0) int queueLength,
  }) = _TableVoiceState;
}
