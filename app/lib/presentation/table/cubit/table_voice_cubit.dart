import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/speech/silent_mode_probe.dart';
import 'package:roundtablezoo/core/speech/speech_synthesizer.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/value_objects/character_voice.dart';
import 'package:roundtablezoo/presentation/table/cubit/table_voice_state.dart';

/// One element of the speech queue (`data-model.md` §4, "Очередь
/// произнесения"). Duplicate `characterId`s are possible and allowed (a
/// re-ask — Assumptions спеки).
class VoiceUtterance {
  const VoiceUtterance({
    required this.characterId,
    required this.text,
    required this.voice,
    required this.languageTag,
  });

  final String characterId;
  final String text;
  final CharacterVoice voice;
  final String languageTag;
}

/// Screen-scoped queue + "who's speaking" for `/table`
/// (`contracts/table-voice-cubit.md`). A fresh instance per visit
/// (`@injectable` factory), same as `TableCubit`/`SettingsCubit`.
/// `TableCubit`/`TableState` are never touched (principle I, V8) — this
/// cubit only reacts to replies `TablePage` hands it and to
/// `SettingsRepository.watch()`.
class TableVoiceCubit extends Cubit<TableVoiceState> {
  TableVoiceCubit({
    required SpeechSynthesizer synthesizer,
    required SilentModeProbe silentModeProbe,
    required SettingsRepository settingsRepository,
  }) : _synthesizer = synthesizer,
       _silentModeProbe = silentModeProbe,
       super(const TableVoiceState()) {
    _settingsSubscription = settingsRepository.watch().listen(_onSettings);
  }

  final SpeechSynthesizer _synthesizer;
  final SilentModeProbe _silentModeProbe;
  late final StreamSubscription<UserSettings> _settingsSubscription;

  final List<VoiceUtterance> _queue = [];
  bool _processing = false;

  bool _soundEnabled = true;
  bool _screenReaderActive = false;
  bool _voiceAvailable = true;

  bool get _gatesOpen => _soundEnabled && _voiceAvailable && !_screenReaderActive;

  void _onSettings(UserSettings settings) {
    final wasEnabled = _soundEnabled;
    _soundEnabled = settings.soundEnabled;
    // FR-008: turning the toggle off during an utterance stops it and
    // clears the queue; turning it back on doesn't resume anything (V9).
    if (wasEnabled && !_soundEnabled) unawaited(stopAll());
  }

  /// Queues a newly-shown reply, starting playback if all gates are open
  /// (`data-model.md` §5); otherwise a no-op — the reply is simply never
  /// spoken.
  void enqueue({
    required String characterId,
    required String text,
    required CharacterVoice voice,
    required String languageTag,
  }) {
    if (isClosed || !_gatesOpen) return;
    _queue.add(
      VoiceUtterance(characterId: characterId, text: text, voice: voice, languageTag: languageTag),
    );
    _emitQueueLength();
    unawaited(_processQueue());
  }

  void onScreenReaderChanged({required bool active}) {
    if (_screenReaderActive == active) return;
    _screenReaderActive = active;
    if (active) unawaited(stopAll());
  }

  void onVoiceAvailabilityChanged({required bool available}) {
    if (_voiceAvailable == available) return;
    _voiceAvailable = available;
    if (!available) unawaited(stopAll());
  }

  /// Clears the queue, stops the engine and resets `speakingCharacterId` —
  /// the single stop-condition handler (research.md R11). Called from a
  /// screen leaving/backgrounding, a new reaction cycle, the sound toggle
  /// turning off, a screen reader turning on, and `close()`.
  Future<void> stopAll() async {
    _queue.clear();
    if (!isClosed) emit(state.copyWith(speakingCharacterId: null, queueLength: 0));
    await _synthesizer.stop();
  }

  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      while (_queue.isNotEmpty) {
        if (isClosed) return;
        final utterance = _queue.removeAt(0);
        _emitQueueLength();

        // FR-011b: checked right before speaking, not at enqueue time —
        // the mode can change while a reply waits in the queue (V4).
        final silent = await _silentModeProbe.isSilent();
        if (isClosed) return;
        if (silent) continue;

        emit(state.copyWith(speakingCharacterId: utterance.characterId));
        // Any `Result.failure` here is swallowed on purpose (FR-012,
        // SC-006, V6) — the queue keeps moving either way.
        await _synthesizer.speak(
          SpeechRequest(
            text: utterance.text,
            languageTag: utterance.languageTag,
            voice: utterance.voice,
          ),
        );
        if (isClosed) return;
        emit(state.copyWith(speakingCharacterId: null));
      }
    } finally {
      _processing = false;
    }
  }

  void _emitQueueLength() {
    if (!isClosed) emit(state.copyWith(queueLength: _queue.length));
  }

  @override
  Future<void> close() async {
    await stopAll();
    await _settingsSubscription.cancel();
    return super.close();
  }
}
