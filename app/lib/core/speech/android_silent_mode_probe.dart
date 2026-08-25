import 'package:flutter/services.dart';
import 'package:roundtablezoo/core/speech/silent_mode_probe.dart';
import 'package:roundtablezoo/core/utils/app_logger.dart';

/// Android needs its own platform check: TTS plays on `STREAM_MUSIC`,
/// which the ringer mode doesn't mute and audio focus doesn't report
/// (research.md R7). Backed by `AudioModeChannel.kt`, registered in
/// `MainActivity.configureFlutterEngine` next to `IntegrityChannel`.
class AndroidSilentModeProbe implements SilentModeProbe {
  static const _channel = MethodChannel('life.studyway.roundtablezoo/audio');

  @override
  Future<bool> isSilent() async {
    try {
      final silent = await _channel.invokeMethod<bool>('isSilent');
      return silent ?? false;
    } on Object catch (error, stackTrace) {
      // Better to speak than to lose the feature over a probe failure
      // (`contracts/speech-synthesizer.md` §2).
      logger.e(error.toString(), error: error, stackTrace: stackTrace);
      return false;
    }
  }
}
