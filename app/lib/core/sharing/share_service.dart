import 'dart:convert';

import 'package:share_plus/share_plus.dart';

/// Thin wrapper over `share_plus` so callers stay testable and the
/// Diary's CSV export (005-diary-screen) can reuse the same mechanism
/// (research.md R3, R10).
abstract interface class ShareService {
  Future<void> shareText(String text);

  /// Shares [csv] as a `text/csv` file named [fileName] through the same
  /// system "share" sheet as [shareText] (FR-020, research.md R10).
  Future<void> shareCsv(String csv, {required String fileName});
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

  @override
  Future<void> shareCsv(String csv, {required String fileName}) async {
    // `XFile.fromData` without a path writes the bytes to a temp file
    // itself (verified against
    // `share_plus_platform_interface-7.2.0/lib/method_channel/method_channel_share.dart`),
    // so no `path_provider` bookkeeping is needed here (research.md R10).
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv')],
        fileNameOverrides: [fileName],
      ),
    );
  }
}
