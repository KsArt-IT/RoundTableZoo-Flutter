package life.studyway.roundtablezoo

import android.content.Context
import android.media.AudioManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Single-method channel backing `AndroidSilentModeProbe`
 * (`specs/008-character-voice-tts/contracts/speech-synthesizer.md` §2):
 * TTS plays on `STREAM_MUSIC`, which the ringer mode doesn't mute and
 * audio focus doesn't report, so this reads both signals directly.
 */
class AudioModeChannel(context: Context) : MethodChannel.MethodCallHandler {

    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "isSilent") {
            result.notImplemented()
            return
        }
        val silent = audioManager.ringerMode != AudioManager.RINGER_MODE_NORMAL ||
            audioManager.getStreamVolume(AudioManager.STREAM_MUSIC) == 0
        result.success(silent)
    }
}
