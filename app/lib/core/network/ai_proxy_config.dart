import 'package:flutter/foundation.dart';

/// Address of the ai-proxy backend, injected at build time via
/// `--dart-define=PROXY_BASE_URL=...` (research.md R2). Read once from the
/// environment — never hardcoded, never shipped as an asset.
abstract final class AiProxyConfig {
  const AiProxyConfig._();

  static const String baseUrl = String.fromEnvironment('PROXY_BASE_URL');

  /// Whether a real backend address was supplied at build time. `false`
  /// switches DI to the stub ai-proxy client in debug/profile builds.
  static bool get isConfigured => baseUrl.isNotEmpty;

  /// A release build with no configured proxy must fail loudly instead of
  /// silently shipping with the stub client (SC-012). No-op in
  /// debug/profile, where an unconfigured proxy is the expected default.
  static void assertConfiguredForRelease() {
    if (kReleaseMode && !isConfigured) {
      throw StateError(
        'PROXY_BASE_URL is not configured. Release builds must be built '
        'with --dart-define=PROXY_BASE_URL=<url>.',
      );
    }
  }
}
