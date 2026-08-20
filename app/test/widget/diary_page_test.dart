import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/diary/widgets/diary_day_card.dart';
import 'package:roundtablezoo/presentation/diary/widgets/diary_empty_view.dart';
import 'package:roundtablezoo/presentation/diary/widgets/diary_reactions_list.dart';

import '../support/test_app_root.dart';

Future<AppLocalizations> _renderedLocalizations(WidgetTester tester) => AppLocalizations.delegate
    .load(Localizations.localeOf(tester.element(find.byType(NavigationBar))));

Future<int> _insertEntry(DateTime occurredAt, int moodScore, {String? dayText}) async {
  final db = getIt<AppDatabase>();
  return db
      .into(db.dayEntries)
      .insert(
        DayEntriesCompanion.insert(
          occurredAt: occurredAt,
          moodScore: moodScore,
          dayText: Value(dayText),
          createdAt: occurredAt,
          updatedAt: occurredAt,
        ),
      );
}

Future<void> _insertReaction(
  int dayEntryId, {
  required String characterId,
  required String reply,
  DateTime? createdAt,
}) async {
  final db = getIt<AppDatabase>();
  await db
      .into(db.characterReactions)
      .insert(
        CharacterReactionsCompanion.insert(
          dayEntryId: dayEntryId,
          characterId: characterId,
          reply: reply,
          intensity: 0.5,
          createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
        ),
      );
}

Future<void> _openDiary(WidgetTester tester) async {
  final l10n = await _renderedLocalizations(tester);
  await tester.tap(find.widgetWithText(NavigationDestination, l10n.sectionDiary));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty history shows the empty state, not a blank list (FR-007)', (tester) async {
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    await _openDiary(tester);

    expect(find.byType(DiaryEmptyView), findsOneWidget);
    expect(find.byType(DiaryDayCard), findsNothing);

    await disposeTestAppRoot(tester);
  });

  testWidgets('days are listed newest first (FR-001)', (tester) async {
    final widget = buildTestAppRoot();
    await _insertEntry(DateTime.utc(2026, 1, 1), 2);
    await _insertEntry(DateTime.utc(2026, 1, 3), 5);
    await _insertEntry(DateTime.utc(2026, 1, 2), 3);

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openDiary(tester);

    final cards = tester.widgetList<DiaryDayCard>(find.byType(DiaryDayCard)).toList();
    expect(cards.map((c) => c.day.day.day), [3, 2, 1]);

    await disposeTestAppRoot(tester);
  });

  testWidgets('a day with no text renders without a placeholder (FR-005)', (tester) async {
    final widget = buildTestAppRoot();
    await _insertEntry(DateTime.utc(2026, 1, 1), 4);

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openDiary(tester);

    expect(find.text('null'), findsNothing);

    await disposeTestAppRoot(tester);
  });

  testWidgets('the end of a short list shows "no more days", not a spinner (FR-004c)', (
    tester,
  ) async {
    final widget = buildTestAppRoot();
    await _insertEntry(DateTime.utc(2026, 1, 1), 4);

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openDiary(tester);

    final l10n = await _renderedLocalizations(tester);
    expect(find.text(l10n.diaryNoMoreDays), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await disposeTestAppRoot(tester);
  });

  testWidgets('no day is expanded when the screen opens (FR-014)', (tester) async {
    final widget = buildTestAppRoot();
    await _insertEntry(DateTime.utc(2026, 1, 1), 4);
    await _insertEntry(DateTime.utc(2026, 1, 2), 3);

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openDiary(tester);

    final cards = tester.widgetList<DiaryDayCard>(find.byType(DiaryDayCard)).toList();
    expect(cards.every((c) => !c.day.expanded), isTrue);

    await disposeTestAppRoot(tester);
  });

  testWidgets('expanding a second day does not collapse the first (FR-014, not an accordion)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final widget = buildTestAppRoot();
    await _insertEntry(DateTime.utc(2026, 1, 1), 4);
    await _insertEntry(DateTime.utc(2026, 1, 2), 3);

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openDiary(tester);

    final cardFinder = find.byType(DiaryDayCard);
    await tester.tap(cardFinder.at(0));
    await tester.pumpAndSettle();
    await tester.tap(cardFinder.at(1));
    await tester.pumpAndSettle();

    final cards = tester.widgetList<DiaryDayCard>(cardFinder).toList();
    expect(cards.every((c) => c.day.expanded), isTrue);

    await disposeTestAppRoot(tester);
  });

  testWidgets('a day with no reactions shows "no replies yet", not an empty block (FR-018)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final widget = buildTestAppRoot();
    await _insertEntry(DateTime.utc(2026, 1, 1), 4);

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openDiary(tester);

    await tester.tap(find.byType(DiaryDayCard));
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    expect(find.text(l10n.diaryNoReactions), findsOneWidget);

    await disposeTestAppRoot(tester);
  });

  testWidgets('a reaction from a character outside the catalog shows by characterId (FR-019)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final widget = buildTestAppRoot();
    final entryId = await _insertEntry(DateTime.utc(2026, 1, 1), 4);
    await _insertReaction(entryId, characterId: 'not-in-catalog', reply: 'hello there');

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openDiary(tester);

    await tester.tap(find.byType(DiaryDayCard));
    await tester.pumpAndSettle();

    expect(find.byType(DiaryReactionsList), findsOneWidget);
    expect(find.textContaining('not-in-catalog'), findsOneWidget);

    await disposeTestAppRoot(tester);
  });
}
