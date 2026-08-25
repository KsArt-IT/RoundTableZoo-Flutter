/// Whether the device is currently in a state where speech shouldn't be
/// audible (`contracts/speech-synthesizer.md` §2). Checked immediately
/// before each `speak`, not when an utterance is queued (FR-011b).
abstract interface class SilentModeProbe {
  /// `true` — the device is "silent" right now and speech must not sound.
  Future<bool> isSilent();
}

/// Stand-in for every platform except Android — `ambient` iOS audio
/// category already respects the mute switch, so no platform probe is
/// needed there.
class NoSilentModeProbe implements SilentModeProbe {
  const NoSilentModeProbe();

  @override
  Future<bool> isSilent() async => false;
}
