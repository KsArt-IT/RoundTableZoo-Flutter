import 'package:share_plus/share_plus.dart';

/// Thin wrapper over `share_plus` so callers stay testable and the
/// Diary's future CSV export (`04-requirements-diary.md`) can reuse the
/// same mechanism (research.md R3).
abstract interface class ShareService {
  Future<void> shareText(String text);
}

/// `share_plus-13.3.0`: the static `Share.share(...)` is deprecated in
/// favor of `SharePlus.instance.share(ShareParams(...))` (verified
/// against the source in `~/.pub-cache`, tasks.md T002).
class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  @override
  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
