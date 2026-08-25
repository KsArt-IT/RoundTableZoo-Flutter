import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/domain/value_objects/character_voice.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/table/widgets/character_avatar.dart';

const _character = Character(
  id: 'cat',
  name: 'Кот',
  colorHex: 0xFF8A7CA8,
  fallbackReply: 'Мр-р.',
  maxReplyLength: 220,
  voice: CharacterVoice.neutral,
  idleAnimation: 'assets/lottie/cat_idle.json',
  talkAnimation: 'assets/lottie/cat_talk.json',
);

/// No animation assets — exercises the static branch. `emoji` is set on
/// purpose: it is what the shipped `characters.json` now carries.
const _staticCharacter = Character(
  id: 'cat',
  emoji: '🐱',
  name: 'Кот',
  colorHex: 0xFF8A7CA8,
  fallbackReply: 'Мр-р.',
  maxReplyLength: 220,
  voice: CharacterVoice.neutral,
);

/// Same seat with no emoji — the pre-existing first-letter branch.
const _letterCharacter = Character(
  id: 'cat',
  name: 'Кот',
  colorHex: 0xFF8A7CA8,
  fallbackReply: 'Мр-р.',
  maxReplyLength: 220,
  voice: CharacterVoice.neutral,
);

Widget _wrapped({
  required CharacterVisualState state,
  bool disableAnimations = false,
  Character character = _character,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(
      body: CharacterAvatar(character: character, state: state, onTap: null),
    ),
  ),
);

void main() {
  testWidgets(
    'idle/talk Lottie animation plays normally when "reduce motion" is off',
    (tester) async {
      await tester.pumpWidget(_wrapped(state: CharacterVisualState.idle));

      final lottie = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      expect(lottie.animate, isTrue);
    },
  );

  testWidgets(
    'idle/talk Lottie animation freezes when "reduce motion" is on (FR-033a)',
    (tester) async {
      await tester.pumpWidget(
        _wrapped(state: CharacterVisualState.idle, disableAnimations: true),
      );

      final idleLottie = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      expect(idleLottie.animate, isFalse);

      await tester.pumpWidget(
        _wrapped(state: CharacterVisualState.speaking, disableAnimations: true),
      );

      final talkLottie = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      expect(talkLottie.animate, isFalse);
    },
  );

  testWidgets('static avatar shows the configured emoji instead of a letter', (tester) async {
    await tester.pumpWidget(
      _wrapped(state: CharacterVisualState.idle, character: _staticCharacter),
    );

    expect(find.text('🐱'), findsOneWidget);
    expect(find.text('К'), findsNothing);
  });

  testWidgets('static avatar falls back to the name letter without an emoji', (tester) async {
    await tester.pumpWidget(
      _wrapped(state: CharacterVisualState.idle, character: _letterCharacter),
    );

    expect(find.text('К'), findsOneWidget);
  });

  testWidgets('emoji is not announced — the semantics label stays the name plus state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrapped(state: CharacterVisualState.idle, character: _staticCharacter),
    );

    // FR-012: state is conveyed by the label, and the decorative glyph
    // must not leak into it as an unpronounceable character.
    final semantics = tester.getSemantics(find.byType(CharacterAvatar));
    expect(semantics.label, startsWith('Кот, '));
    expect(semantics.label, isNot(contains('🐱')));

    handle.dispose();
  });

  testWidgets('the tap ripple has its own Material inside the seat', (tester) async {
    await tester.pumpWidget(
      _wrapped(state: CharacterVisualState.idle, character: _staticCharacter),
    );

    // Regression: ink splashes paint into the nearest enclosing `Material`.
    // With only the `Scaffold`'s, the ripple landed underneath
    // `RoundTableLayout`'s table surface `CustomPaint` and was invisible.
    // The seat must carry a transparent `Material` of its own, between the
    // avatar and its ink well.
    final localMaterial = find.descendant(
      of: find.byType(CharacterAvatar),
      matching: find.byType(Material),
    );
    expect(localMaterial, findsOneWidget);
    expect(tester.widget<Material>(localMaterial).type, MaterialType.transparency);
    expect(
      find.descendant(of: localMaterial, matching: find.byType(InkWell)),
      findsOneWidget,
    );
  });

  testWidgets('the seat leaves a halo ring around the drawn avatar', (tester) async {
    await tester.pumpWidget(
      _wrapped(state: CharacterVisualState.idle, character: _staticCharacter),
    );

    // Regression: the seat used to be exactly the avatar's size, so the
    // ripple — painted underneath the disc — had nowhere to show and was
    // sliced by the square box. The footprint must stay strictly larger
    // than the disc, and the ripple clipped to a circle rather than that
    // box.
    final seat = tester.getSize(find.byType(CharacterAvatar));
    expect(seat.width, AppConstants.characterSeatDp);
    expect(seat.height, AppConstants.characterSeatDp);
    expect(AppConstants.characterSeatDp, greaterThan(AppConstants.characterAvatarDp));

    final clipOvalSize = tester.getSize(find.byType(ClipOval));
    expect(clipOvalSize.width, AppConstants.characterAvatarDp);

    // `InkWell`, not `InkResponse`: `customBorder` is only honored by a
    // *contained* ink well. On a bare `InkResponse` it is silently
    // ignored and the ripple stays square.
    final ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.customBorder, isA<CircleBorder>());
    expect(ink.containedInkWell, isTrue);
  });

  testWidgets('the seat still meets the minimum tap target', (tester) async {
    await tester.pumpWidget(
      _wrapped(state: CharacterVisualState.idle, character: _staticCharacter),
    );

    final seat = tester.getSize(find.byType(CharacterAvatar));
    expect(seat.shortestSide, greaterThanOrEqualTo(AppConstants.minTapTargetDp));
  });
}
