import 'package:flutter/services.dart';
import 'package:roundtablezoo/core/integrity/integrity_token_provider.dart';

/// Android implementation — a single `MethodChannel` call to
/// `IntegrityChannel.kt` (`specs/007-ai-proxy/contracts/integrity-token-provider.md`
/// §4). The token is cached for the whole process (research.md R4): once
/// fetched, every later [token] call returns the same value without
/// touching the platform again, until [invalidate] clears it.
class PlayIntegrityTokenProvider implements IntegrityTokenProvider {
  PlayIntegrityTokenProvider({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('life.studyway.roundtablezoo/integrity');

  final MethodChannel _channel;

  String? _cached;

  /// Shared by every caller that arrives while a platform request is
  /// already in flight, so concurrent taps on an empty cache produce
  /// exactly one `requestToken` call (contracts/integrity-token-provider.md
  /// §1), not one per caller.
  Future<String?>? _inFlight;

  @override
  Future<String?> token() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);

    return _inFlight ??= _requestToken().whenComplete(() => _inFlight = null);
  }

  Future<String?> _requestToken() async {
    try {
      final token = await _channel.invokeMethod<String>('requestToken');
      _cached = token;
      return token;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  void invalidate() {
    // Only [_cached] is cleared here — not [_inFlight]. A request already in
    // flight was not started with the stale token: it always calls the
    // platform channel fresh, so its eventual result already satisfies this
    // call. Nulling [_inFlight] out from under a request another caller
    // started would drop the shared future and let a second concurrent
    // platform call race it, one of which can overwrite [_cached] with a
    // token older than the other — breaking the single-in-flight-call
    // invariant documented on [_inFlight].
    _cached = null;
  }
}
