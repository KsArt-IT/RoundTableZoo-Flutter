/// The four states a seat at the table can be in (FR-011).
///
/// Lives in its own file rather than inside `character_avatar.dart` so the
/// animation layer (`TalkPose`, `TalkPoseDriver`) can depend on it without
/// depending on the widget that renders it. `character_avatar.dart`
/// re-exports it, so every existing import keeps working.
enum CharacterVisualState {
  idle,
  waiting,

  /// The reply is being revealed or read aloud right now — the only state
  /// whose duration is driven from outside the avatar (`SpeakingBubble`'s
  /// reveal, then `TableVoiceCubit`'s queue).
  speaking,
  answered,
}
