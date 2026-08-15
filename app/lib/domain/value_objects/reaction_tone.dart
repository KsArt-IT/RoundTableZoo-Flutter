/// Tone of a character's reply. Storage never rejects a reaction over its
/// tone — an unrecognized value maps to [neutral] instead (FR-010b).
enum ReactionTone {
  neutral,
  warm,
  playful,
  dry,
  sad,
  encouraging;

  /// Maps a stored/incoming name to a [ReactionTone], defaulting to
  /// [neutral] when [name] doesn't match a known value.
  static ReactionTone fromStorage(String? name) =>
      ReactionTone.values.firstWhere((tone) => tone.name == name, orElse: () => neutral);
}
