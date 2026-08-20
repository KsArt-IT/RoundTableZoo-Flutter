import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';

/// Formats the full saved history as CSV (contracts/csv-export.md). Walks
/// `entriesPage` in `AppConstants.diaryExportBatchSize`-sized pages instead
/// of one unbounded query, so peak memory stays bounded and reactions are
/// batch-fetched per page rather than one `reactionsFor` call per day
/// (research.md R9, R11). Neither `DayResolver` nor `AppClock` are needed
/// here — the day is already computed by the repository
/// (`DiaryDayEntry.day`), and the export doesn't need "now" for anything;
/// the CSV file name is built by `DiaryCubit.export()` instead.
class ExportDiaryToCsv {
  ExportDiaryToCsv({required DiaryRepository repository}) : _repository = repository;

  final DiaryRepository _repository;

  static const _header = 'date,moodScore,dayText,characterId,characterReply\r\n';

  Future<Result<String>> call() async {
    final buffer = StringBuffer(_header);
    DateTime? cursor;
    var wroteAnyRow = false;

    while (true) {
      final pageResult = await _repository.entriesPage(
        beforeOccurredAt: cursor,
        limit: AppConstants.diaryExportBatchSize,
      );
      if (pageResult.isFailure) return Result.failure(pageResult.errorOrNull!);
      final page = pageResult.valueOrNull!;
      if (page.days.isEmpty) break;

      // Every day on a page came straight out of the database, so its
      // entry always has a persisted id (contracts/diary-repository.md §1).
      final entryIds = [for (final day in page.days) day.entry.id!];
      final reactionsResult = await _repository.reactionsForEntries(entryIds);
      if (reactionsResult.isFailure) return Result.failure(reactionsResult.errorOrNull!);
      final reactionsByEntry = reactionsResult.valueOrNull!;

      for (final day in page.days) {
        final reactions = reactionsByEntry[day.entry.id] ?? const [];
        final dateField = day.day.toString();
        final moodField = day.entry.moodScore.value.toString();
        final dayTextField = day.entry.dayText ?? '';

        if (reactions.isEmpty) {
          buffer.write(_row([dateField, moodField, dayTextField, '', '']));
        } else {
          for (final reaction in reactions) {
            buffer.write(
              _row([dateField, moodField, dayTextField, reaction.characterId, reaction.reply]),
            );
          }
        }
        wroteAnyRow = true;
      }

      if (!page.hasMore) break;
      cursor = page.nextCursor;
      // Yields the event loop between pages so a large export doesn't
      // block the UI thread in one long synchronous stretch (SC-005).
      await Future<void>.delayed(Duration.zero);
    }

    if (!wroteAnyRow) {
      return const Result.failure(ValidationFailure('exportDiaryToCsv: history is empty'));
    }
    return Result.success(buffer.toString());
  }

  String _row(List<String> fields) => '${fields.map(_escapeField).join(',')}\r\n';

  /// RFC 4180: quote a field iff it contains `,`, `"`, `\r` or `\n`;
  /// double any internal `"` (contracts/csv-export.md §3).
  String _escapeField(String field) {
    final needsQuoting =
        field.contains(',') || field.contains('"') || field.contains('\r') || field.contains('\n');
    if (!needsQuoting) return field;
    return '"${field.replaceAll('"', '""')}"';
  }
}
