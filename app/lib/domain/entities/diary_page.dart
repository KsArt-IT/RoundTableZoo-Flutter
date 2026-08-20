import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/domain/entities/diary_day_entry.dart';

part 'diary_page.freezed.dart';

/// One keyset-paginated page of Diary history (contracts/diary-repository.md
/// §1). `hasMore`/`nextCursor` are computed by the repository — it's the
/// only layer that sees row counts before day-collapsing.
@freezed
abstract class DiaryPage with _$DiaryPage {
  const factory DiaryPage({
    required List<DiaryDayEntry> days,
    required bool hasMore,
    DateTime? nextCursor,
  }) = _DiaryPage;
}
