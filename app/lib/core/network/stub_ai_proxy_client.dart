import 'package:flutter/foundation.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/network/ai_proxy_client.dart';
import 'package:roundtablezoo/data/models/ai_reaction_dto.dart';

/// Stands in for the real ai-proxy until it exists (research.md R14) —
/// selected in DI whenever `AiProxyConfig.isConfigured` is `false`. Never
/// makes a network call.
class StubAiProxyClient implements AiProxyClient {
  static AiProxyFailure? _queuedFailure;

  /// Forces the next [react] call to fail with [failure] instead of
  /// returning a reply — same one-shot pattern as `DebugFailureInjector`,
  /// for manually walking through all five branches of
  /// `contracts/ai-proxy-client.md` §4 without a real proxy.
  static void enqueueFailure(AiProxyFailure failure) {
    if (kReleaseMode) return;
    _queuedFailure = failure;
  }

  static void clearFailure() => _queuedFailure = null;

  static const _replyTemplates = <String, String Function(String)>{
    'cat': _catReply,
    'dog': _dogReply,
    'crocodile': _crocodileReply,
    'hippo': _hippoReply,
  };

  static const _intensityByCharacter = <String, double>{
    'cat': 0.3,
    'dog': 0.8,
    'crocodile': 0.4,
    'hippo': 0.6,
  };

  static String _catReply(String text) => 'Мр-р... "$text"? Как скажешь.';

  static String _dogReply(String text) => 'Гав-гав! Про "$text" — звучит здорово!';

  static String _crocodileReply(String text) => 'Хм. "$text"... я подумаю об этом.';

  static String _hippoReply(String text) => 'Ох, "$text" — понимаю, бывает тяжело.';

  @override
  Future<AiReactionDto> react({
    required String installId,
    required String characterId,
    required String dayText,
  }) async {
    // Keeps the waiting state visible in manual QA (FR-016) instead of
    // resolving instantly.
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    final failure = _queuedFailure;
    if (failure != null) {
      _queuedFailure = null;
      throw failure;
    }

    final template = _replyTemplates[characterId];
    final reply = template != null
        ? template(_firstWords(dayText))
        // Any character outside the MVP roster still gets a reply that
        // visibly differs from the four above (SC-003a doesn't apply
        // beyond them, but nothing here should look broken either).
        : '[$characterId] Слышал: "${_firstWords(dayText)}"';

    return AiReactionDto(
      character: characterId,
      mood: 'neutral',
      reply: reply,
      intensity: _intensityByCharacter[characterId] ?? 0.5,
    );
  }

  static String _firstWords(String text, {int maxWords = 6}) {
    final words = text.trim().split(RegExp(r'\s+'));
    return words.take(maxWords).join(' ');
  }
}
