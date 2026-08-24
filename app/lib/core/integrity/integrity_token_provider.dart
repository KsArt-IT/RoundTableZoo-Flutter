/// Client half of the Play Integrity handshake
/// (`specs/007-ai-proxy/contracts/integrity-token-provider.md`). Lives in
/// `core/` because it's a platform mechanism, not a business rule —
/// neither `domain/` nor `data/` know it exists (principle I).
abstract interface class IntegrityTokenProvider {
  /// Returns the cached token, requesting one from the platform on first
  /// call and caching it for the rest of the process (Clarifications Q2).
  /// Never throws: any platform failure surfaces as `null`, and the caller
  /// sends the request without a token rather than giving up on it — the
  /// service decides whether that's acceptable (research.md R14).
  Future<String?> token();

  /// Clears the cache. Idempotent. The next [token] call requests a fresh
  /// one. Called exactly once by `DioAiProxyClient` after a `403`
  /// (FR-010a).
  void invalidate();
}

/// Selected on every platform except Android (research.md R14) — Play
/// Integrity has no equivalent there, and this app publishes to Android
/// only. Requests go out without `integrityToken`; the production service
/// rejects them with `403`, which the client turns into
/// `AiProxyFailure.integrityRejected`.
class UnsupportedIntegrityTokenProvider implements IntegrityTokenProvider {
  const UnsupportedIntegrityTokenProvider();

  @override
  Future<String?> token() async => null;

  @override
  void invalidate() {}
}
