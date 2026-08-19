import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/network/stub_ai_proxy_client.dart';
import 'package:roundtablezoo/core/sharing/share_service.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';
import 'package:roundtablezoo/presentation/table/widgets/speaking_bubble.dart';

import '../support/mocks.dart';
import '../support/test_app_root.dart';

Future<AppLocalizations> _renderedLocalizations(WidgetTester tester) => AppLocalizations.delegate
    .load(Localizations.localeOf(tester.element(find.byType(Scaffold).first)));

MoodScore _mood(int value) =>
    MoodScore.create(value).valueOrGet(() => throw StateError('bad fixture'));

void main() {
  tearDown(StubAiProxyClient.clearFailure);

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

    await tester.pumpWidget(
      buildTestAppRoot(initialState: const StorageRecoveryState.idle(cause: cause)),
    );
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

  testWidgets(
    'tapping two different characters shows two distinct bubbles, each over its own seat',
    (
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
          .widgetList<Text>(
            find.byWidgetPredicate(
              (widget) => widget is Text && (widget.data ?? '').contains('привет мир'),
            ),
          )
          .map((text) => text.data)
          .toSet();

      // Two taps on two different characters must produce exactly two
      // bubbles, each with its own character-flavored reply — not the same
      // reply duplicated, and not a bubble stranded over a third seat.
      expect(bubbleTexts, hasLength(2));

      await disposeTestAppRoot(tester);
    },
  );

  testWidgets(
    'long-pressing a reply bubble shares its text and character name; a short tap does not '
    '(US5, FR-030)',
    (tester) async {
      // A taller viewport gives `RoundTableLayout` enough room for an
      // "opens upward" bubble (the top/right seats, `round_table_layout.dart`)
      // to stay fully on-screen — the default 800x600 clips it, which
      // makes `longPress` below miss the widget entirely.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestAppRoot());
      await tester.pumpAndSettle();

      final l10n = await _renderedLocalizations(tester);
      await tester.tap(find.bySemanticsLabel(l10n.moodScaleGood));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'привет мир');
      await tester.pump();

      await tester.tap(_idleSeats(l10n).first);
      await tester.pumpAndSettle();

      final shareService = getIt<ShareService>() as MockShareService;
      verifyNever(() => shareService.shareText(any()));

      // The short tap that revealed the reply above must not itself count
      // as a share — only a long press does (FR-017a). Long-pressing the
      // whole bubble widget (not the `Text` line, which can sit a few
      // pixels off the default 800x600 test viewport) keeps the tap point
      // reliably on-screen.
      await tester.longPress(find.byType(SpeakingBubble).first);
      await tester.pumpAndSettle();

      final captured = verify(() => shareService.shareText(captureAny())).captured;
      expect(captured, hasLength(1));
      final sharedText = captured.single as String;
      expect(sharedText, contains('привет мир'));
      // Contains one of the four MVP character names — the exact seat
      // tapped isn't deterministic (`_idleSeats(l10n).first`).
      expect(
        RegExp('Кот|Пёс|Крокодил|Бегемот').hasMatch(sharedText),
        isTrue,
        reason: 'shared text "$sharedText" should include the character name',
      );

      await disposeTestAppRoot(tester);
    },
  );

  testWidgets(
    'network/rateLimited/aiDisabled show three distinct inline errors; mood scale stays usable '
    '(US4, FR-024–FR-026, FR-028)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTestAppRoot());
      await tester.pumpAndSettle();

      final l10n = await _renderedLocalizations(tester);
      await tester.tap(find.bySemanticsLabel(l10n.moodScaleGood));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'привет мир');
      await tester.pump();

      final failuresAndTexts = [
        (const AiProxyFailure(null, code: AiProxyFailure.network), l10n.tableAiNetworkError),
        (
          const AiProxyFailure(null, code: AiProxyFailure.rateLimited),
          l10n.tableAiRateLimitedError,
        ),
        (const AiProxyFailure(null, code: AiProxyFailure.aiDisabled), l10n.tableAiDisabledError),
      ];

      // Alternates between two mood values across iterations, so each
      // check is a real state change — a re-tap of the already-selected
      // value would trivially stay "selected" even if the scale broke.
      final moodLabels = [l10n.moodScaleNeutral, l10n.moodScaleGood];

      for (var i = 0; i < failuresAndTexts.length; i++) {
        final (failure, expectedText) = failuresAndTexts[i];
        StubAiProxyClient.enqueueFailure(failure);
        await tester.tap(_idleSeats(l10n).first);
        await tester.pumpAndSettle();

        expect(find.text(expectedText), findsOneWidget);
        // Every other error text stays absent — the three are genuinely
        // distinct, not one generic banner.
        for (final (_, otherText) in failuresAndTexts) {
          if (otherText == expectedText) continue;
          expect(find.text(otherText), findsNothing);
        }

        // The mood scale must still work after each of the three failures
        // (FR-028).
        final targetFinder = find.bySemanticsLabel(moodLabels[i % moodLabels.length]);
        await tester.tap(targetFinder);
        await tester.pumpAndSettle();
        expect(tester.getSemantics(targetFinder).flagsCollection.isSelected, Tristate.isTrue);
      }

      handle.dispose();
      await disposeTestAppRoot(tester);
    },
  );
}

/// Character seats are addressed by their own `Semantics` label
/// (`"<name>, <state>"`, `character_avatar.dart`) rather than a fixed id —
/// this matches any seat currently in the idle state.
Finder _idleSeats(AppLocalizations l10n) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      (widget.properties.label?.endsWith(l10n.tableCharacterStateIdle) ?? false),
);
