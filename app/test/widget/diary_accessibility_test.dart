import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/diary/widgets/diary_day_card.dart';

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

Future<void> _insertReaction(int dayEntryId) async {
  final db = getIt<AppDatabase>();
  await db
      .into(db.characterReactions)
      .insert(
        CharacterReactionsCompanion.insert(
          dayEntryId: dayEntryId,
          characterId: 'cat',
          reply: 'meow',
          intensity: 0.5,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
}

Future<void> _openDiary(WidgetTester tester) async {
  final l10n = await _renderedLocalizations(tester);
  await tester.tap(find.widgetWithText(NavigationDestination, l10n.sectionDiary));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'an expanded day and the active export button meet Android tap-target and label '
    'guidelines (FR-030, SC-006)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final handle = tester.ensureSemantics();
      final widget = buildTestAppRoot();
      final entryId = await _insertEntry(DateTime.utc(2026, 1, 1), 4, dayText: 'a good day');
      await _insertReaction(entryId);

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await _openDiary(tester);

      await tester.tap(find.byType(DiaryDayCard));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
      await disposeTestAppRoot(tester);
    },
  );

  testWidgets('the disabled export button on an empty history still meets label guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();
    await _openDiary(tester);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
    await disposeTestAppRoot(tester);
  });

  testWidgets('a day card does not overflow at 2x text scale (research.md R19)', (tester) async {
    final widget = buildTestAppRoot();
    final entryId = await _insertEntry(
      DateTime.utc(2026, 1, 1),
      4,
      dayText: 'a fairly long day text that could wrap across several lines on a small screen',
    );
    await _insertReaction(entryId);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: widget,
      ),
    );
    await tester.pumpAndSettle();
    await _openDiary(tester);

    await tester.tap(find.byType(DiaryDayCard));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await disposeTestAppRoot(tester);
  });
}
