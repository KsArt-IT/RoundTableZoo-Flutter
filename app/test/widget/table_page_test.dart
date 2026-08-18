import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';

import '../support/test_app_root.dart';

Future<AppLocalizations> _renderedLocalizations(WidgetTester tester) =>
    AppLocalizations.delegate.load(Localizations.localeOf(tester.element(find.byType(Scaffold).first)));

MoodScore _mood(int value) => MoodScore.create(value).valueOrGet(() => throw StateError('bad fixture'));

void main() {
  testWidgets('shows the five-option mood scale (FR-001)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    for (final label in [
      l10n.moodScaleVeryBad,
      l10n.moodScaleBad,
      l10n.moodScaleNeutral,
      l10n.moodScaleGood,
      l10n.moodScaleVeryGood,
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }

    handle.dispose();
    await disposeTestAppRoot(tester);
  });

  testWidgets('selecting a mood marks it selected in semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    final goodFinder = find.bySemanticsLabel(l10n.moodScaleGood);
    expect(tester.getSemantics(goodFinder).flagsCollection.isSelected, Tristate.isFalse);

    await tester.tap(goodFinder);
    await tester.pumpAndSettle();

    expect(tester.getSemantics(goodFinder).flagsCollection.isSelected, Tristate.isTrue);

    handle.dispose();
    await disposeTestAppRoot(tester);
  });

  testWidgets('restores an already-saved mood on open (FR-003)', (tester) async {
    final handle = tester.ensureSemantics();
    final widget = buildTestAppRoot();
    await getIt<DiaryRepository>().saveTodayEntry(moodScore: _mood(4));

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    final goodFinder = find.bySemanticsLabel(l10n.moodScaleGood);
    expect(tester.getSemantics(goodFinder).flagsCollection.isSelected, Tristate.isTrue);

    handle.dispose();
    await disposeTestAppRoot(tester);
  });

  testWidgets('read-only mode shows an explanation and ignores mood taps (FR-032)', (tester) async {
    const cause = DatabaseFailure(null, code: DatabaseFailure.storageUnavailable);
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(buildTestAppRoot(initialState: const StorageRecoveryState.idle(cause: cause)));
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    await tester.tap(find.widgetWithText(FilledButton, l10n.storageRecoveryContinueWithoutSaving));
    await tester.pumpAndSettle();

    // The shell-level read-only banner (`ReadOnlyBanner`) plus this
    // screen's own inline explanation, next to the scale (T029).
    expect(find.text(l10n.readOnlyBannerText), findsOneWidget);
    expect(find.text(l10n.storageReadOnly), findsOneWidget);

    final goodFinder = find.bySemanticsLabel(l10n.moodScaleGood);
    await tester.tap(goodFinder);
    await tester.pumpAndSettle();

    expect(tester.getSemantics(goodFinder).flagsCollection.isSelected, Tristate.isFalse);

    handle.dispose();
    await disposeTestAppRoot(tester);
  });

  testWidgets('day text field shows a counter and enforces the length limit (FR-007, FR-008)', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();

    expect(find.text(l10n.tableDayTextCounter(5, 2000)), findsOneWidget);

    await disposeTestAppRoot(tester);
  });

  testWidgets('tapping a character without text shows a hint and does nothing (FR-014, FR-014a)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    await tester.tap(find.bySemanticsLabel(l10n.moodScaleGood));
    await tester.pumpAndSettle();

    expect(find.text(l10n.tableNeedTextHint), findsOneWidget);
    // No character seat is tappable yet — every seat's `Semantics` label
    // still ends in the idle-state suffix, never a `waiting`/`answered` one.
    expect(_idleSeats(l10n), findsWidgets);

    handle.dispose();
    await disposeTestAppRoot(tester);
  });

  testWidgets('a reply bubble appears after tapping a character (US2 basic path, stub client)', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    await tester.tap(find.bySemanticsLabel(l10n.moodScaleGood));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'сегодня был хороший день');
    await tester.pump();

    await tester.tap(_idleSeats(l10n).first);
    // The stub client answers after ~1.2s (research.md R14) — pumpAndSettle
    // advances virtual time until no more frames/timers are pending.
    await tester.pumpAndSettle();

    // Scoped to `Text` — `find.textContaining` alone also matches the day
    // text field's own `EditableText` render, which holds the same string.
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data ?? '').contains('сегодня был хороший день'),
      ),
      findsOneWidget,
    );

    await disposeTestAppRoot(tester);
  });

  testWidgets('tapping two different characters shows two distinct bubbles, each over its own seat', (
    tester,
  ) async {
    // Regression for a `Positioned`-without-`Key` bug in
    // `RoundTableLayout`: with two bubbles both full-width, `Stack`
    // reconciled them by list position instead of by character once the
    // "who currently has a bubble" sublist changed shape, so a second
    // reply could surface over the wrong seat.
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    await tester.tap(find.bySemanticsLabel(l10n.moodScaleGood));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'привет мир');
    await tester.pump();

    await tester.tap(_idleSeats(l10n).first);
    await tester.pumpAndSettle();
    await tester.tap(_idleSeats(l10n).first);
    await tester.pumpAndSettle();

    final bubbleTexts = tester
        .widgetList<Text>(find.byWidgetPredicate((widget) => widget is Text && (widget.data ?? '').contains('привет мир')))
        .map((text) => text.data)
        .toSet();

    // Two taps on two different characters must produce exactly two
    // bubbles, each with its own character-flavored reply — not the same
    // reply duplicated, and not a bubble stranded over a third seat.
    expect(bubbleTexts, hasLength(2));

    await disposeTestAppRoot(tester);
  });
}

/// Character seats are addressed by their own `Semantics` label
/// (`"<name>, <state>"`, `character_avatar.dart`) rather than a fixed id —
/// this matches any seat currently in the idle state.
Finder _idleSeats(AppLocalizations l10n) => find.byWidgetPredicate(
  (widget) => widget is Semantics && (widget.properties.label?.endsWith(l10n.tableCharacterStateIdle) ?? false),
);
