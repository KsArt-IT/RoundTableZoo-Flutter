import 'package:drift/drift.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/domain/entities/day_entry.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';

extension DayEntryRowMapper on DayEntryRow {
  DayEntry toEntity() => DayEntry(
    id: id,
    // sqlite3/drift round-trips the same instant but drops the UTC flag on
    // the way back out — every timestamp in this app is UTC by contract
    // (data-model.md), so restore it here rather than at every call site.
    occurredAt: occurredAt.toUtc(),
    // The CHECK(moodScore BETWEEN 1 AND 5) constraint already guarantees
    // this succeeds; a failure here means the schema constraint itself was
    // bypassed (e.g. hand-edited row), which is a bug worth surfacing loudly.
    moodScore: MoodScore.create(moodScore).valueOrGet(
      () => throw StateError('day_entries.moodScore=$moodScore violates its CHECK constraint'),
    ),
    dayText: dayText,
    createdAt: createdAt.toUtc(),
    updatedAt: updatedAt.toUtc(),
  );
}

extension DayEntryCompanionMapper on DayEntry {
  DayEntriesCompanion toInsertCompanion() => DayEntriesCompanion.insert(
    occurredAt: occurredAt,
    moodScore: moodScore.value,
    dayText: Value(dayText),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
