import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/domain/value_objects/character_voice.dart';
import 'package:roundtablezoo/domain/value_objects/face_shape.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/table/widgets/animal_face_painter.dart';
import 'package:roundtablezoo/presentation/table/widgets/animal_shape.dart';
import 'package:roundtablezoo/presentation/table/widgets/character_avatar.dart';
import 'package:roundtablezoo/presentation/table/widgets/talk_pose.dart';
import 'package:roundtablezoo/presentation/table/widgets/talk_pose_driver.dart';

/// The shipped cat: an emoji *and* a drawn face, so the test also pins down
/// which of the two wins.
const _cat = Character(
  id: 'cat',
  emoji: '🐱',
  face: FaceShape.cat,
  name: 'Кот',
  colorHex: 0xFF8A7CA8,
  fallbackReply: 'Мр-р.',
  maxReplyLength: 220,
  voice: CharacterVoice.neutral,
);

/// The dog: same config shape, a different drawn animal.
const _dog = Character(
  id: 'dog',
  emoji: '🐶',
  face: FaceShape.dog,
  name: 'Пёс',
  colorHex: 0xFFD98C4A,
  fallbackReply: 'Гав!',
  maxReplyLength: 220,
  voice: CharacterVoice.neutral,
);

/// The crocodile: no ears, no whiskers, and a mouth that is not an ellipse.
const _crocodile = Character(
  id: 'crocodile',
  emoji: '🐊',
  face: FaceShape.crocodile,
  name: 'Крокодил',
  colorHex: 0xFF5C8A5C,
  fallbackReply: 'Хм.',
  maxReplyLength: 220,
  voice: CharacterVoice.neutral,
);

/// The hippo: standing, so its far legs are painted under the body.
const _hippo = Character(
  id: 'hippo',
  emoji: '🦛',
  face: FaceShape.hippo,
  name: 'Бегемот',
  colorHex: 0xFF6E8FAE,
  fallbackReply: 'Дай подумать...',
  maxReplyLength: 220,
  voice: CharacterVoice.neutral,
);

Widget _avatar({
  required CharacterVisualState state,
  bool disableAnimations = false,
  double intensity = 1,
  bool mirrored = false,
  Character character = _cat,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(
      body: CharacterAvatar(
        character: character,
        state: state,
        onTap: null,
        intensity: intensity,
        mirrored: mirrored,
      ),
    ),
  ),
);

/// Builds a bare driver and hands back the pose stream it publishes.
Future<ValueListenable<TalkPose>> _pumpDriver(
  WidgetTester tester, {
  required CharacterVisualState state,
  bool animate = true,
  double intensity = 1,
}) async {
  late ValueListenable<TalkPose> poses;
  await tester.pumpWidget(
    TalkPoseDriver(
      state: state,
      intensity: intensity,
      seed: 3,
      animate: animate,
      builder: (context, pose) {
        poses = pose;
        return const SizedBox(width: 72, height: 72);
      },
    ),
  );
  return poses;
}

/// Brings any running ticker to a stop. `flutter_test` fails a test that
/// ends with a live `Ticker` ("was started and is still running"), so every
/// test that sets a seat talking has to put it back down afterwards.
Future<void> _settleDriver(WidgetTester tester) async {
  await _pumpDriver(tester, state: CharacterVisualState.idle, animate: false);
  await tester.pumpAndSettle();
}

Future<List<TalkPose>> _collect(
  WidgetTester tester,
  ValueListenable<TalkPose> poses,
  int frames,
) async {
  final seen = <TalkPose>[];
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    seen.add(poses.value);
  }
  return seen;
}

void main() {
  group('CharacterAvatar with a drawn face', () {
    testWidgets('draws the cat instead of falling back to the emoji glyph', (tester) async {
      await tester.pumpWidget(_avatar(state: CharacterVisualState.idle));

      final painters = tester
          .widgetList<CustomPaint>(
            find.descendant(of: find.byType(CharacterAvatar), matching: find.byType(CustomPaint)),
          )
          .map((paint) => paint.painter);

      expect(painters.whereType<AnimalFacePainter>(), isNotEmpty);
      expect(find.text('🐱'), findsNothing);
    });

    testWidgets('is laid out at the avatar\'s full size, not collapsed to nothing', (
      tester,
    ) async {
      await tester.pumpWidget(_avatar(state: CharacterVisualState.idle));

      final paint = tester
          .widgetList<CustomPaint>(
            find.descendant(of: find.byType(CharacterAvatar), matching: find.byType(CustomPaint)),
          )
          .firstWhere((widget) => widget.painter is AnimalFacePainter);

      // Regression: a childless `CustomPaint` falls back to its `size`
      // argument, and a non-positioned `Stack` child is laid out with
      // *loose* constraints — so without an explicit size the cat ticked
      // away happily at Size.zero and drew nothing on screen.
      expect(paint.size, const Size.square(AppConstants.characterAvatarDp));
      expect(
        tester.getSize(find.byWidget(paint)),
        const Size.square(AppConstants.characterAvatarDp),
      );
    });

    testWidgets('is not clipped to a circle — the tail and paws reach past it', (tester) async {
      await tester.pumpWidget(_avatar(state: CharacterVisualState.idle));

      final paint = tester
          .widgetList<CustomPaint>(
            find.descendant(of: find.byType(CharacterAvatar), matching: find.byType(CustomPaint)),
          )
          .firstWhere((widget) => widget.painter is AnimalFacePainter);

      expect(
        find.ancestor(of: find.byWidget(paint), matching: find.byType(ClipOval)),
        findsNothing,
      );
    });

    testWidgets('each character is drawn with its own shape, one painter for both', (
      tester,
    ) async {
      Future<AnimalShape> shapeOf(Character character) async {
        await tester.pumpWidget(_avatar(state: CharacterVisualState.idle, character: character));
        final painter = tester
            .widgetList<CustomPaint>(
              find.descendant(of: find.byType(CharacterAvatar), matching: find.byType(CustomPaint)),
            )
            .map((widget) => widget.painter)
            .whereType<AnimalFacePainter>()
            .single;
        return painter.shape;
      }

      expect(await shapeOf(_cat), AnimalShape.cat);
      expect(await shapeOf(_dog), AnimalShape.dog);
      expect(await shapeOf(_crocodile), AnimalShape.crocodile);
      expect(await shapeOf(_hippo), AnimalShape.hippo);
      // Species is geometry, not behaviour: all three differ in shape alone.
      expect(AnimalShape.cat.ears, EarStyle.pointed);
      expect(AnimalShape.dog.ears, EarStyle.floppy);
      expect(AnimalShape.crocodile.ears, EarStyle.none);
      expect(AnimalShape.cat.whiskers, isTrue);
      expect(AnimalShape.crocodile.mouth, isNull);
      expect(AnimalShape.crocodile.jaw, isNotNull);
      // The hippo is the only one standing, and the only one whose far legs
      // are painted under the body rather than over it.
      expect(AnimalShape.hippo.haunch, isNull);
      expect(AnimalShape.hippo.legs.where((leg) => leg.behind).length, 2);
      // The cat hides one foreleg behind its torso; the crocodile lies too
      // flat for a far side to read at all, so nothing of its is behind.
      expect(AnimalShape.cat.legs.where((leg) => leg.behind).length, 1);
      expect(AnimalShape.crocodile.legs.every((leg) => !leg.behind), isTrue);
    });

    testWidgets('the crocodile\'s jaw opens downward, not into its own skull', (tester) async {
      final jaw = AnimalShape.crocodile.jaw!;

      // Regression, and the reason `JawShape` documents its sign: the muzzle
      // points left, so a *positive* (clockwise) rotation lifts everything
      // left of the hinge. With the sign flipped the mouth looked like it
      // opened inside the head — it was closing upward.
      expect(jaw.restDegrees, isNegative);
      expect(jaw.swingDegrees, isNegative);

      // And the hinge is the corner where the jaws meet, not a point inside
      // the lower slab — otherwise its own back edge swings up into the skull.
      expect(jaw.hinge.dy, 63);
    });

    testWidgets('faces the way the seat asks it to', (tester) async {
      Future<bool> mirroredOf({required bool mirrored}) async {
        await tester.pumpWidget(
          _avatar(state: CharacterVisualState.idle, mirrored: mirrored, character: _hippo),
        );
        return tester
            .widgetList<CustomPaint>(
              find.descendant(of: find.byType(CharacterAvatar), matching: find.byType(CustomPaint)),
            )
            .map((widget) => widget.painter)
            .whereType<AnimalFacePainter>()
            .single
            .mirrored;
      }

      // Every shape is authored facing left; a seat on the table's left
      // half flips it so the character doesn't turn its back on the table.
      expect(await mirroredOf(mirrored: false), isFalse);
      expect(await mirroredOf(mirrored: true), isTrue);
    });

    testWidgets('a mirrored seat is actually drawn flipped, not merely flagged', (tester) async {
      // The flag reached the painter and was then ignored inside `paint()`
      // — the character kept facing away from the table and no test noticed,
      // because every assertion stopped at the parameter. This one paints.
      Future<Uint8List> render({required bool mirrored}) async {
        final pose = ValueNotifier<TalkPose>(TalkPose.still);
        final recorder = ui.PictureRecorder();
        AnimalFacePainter(
          pose: pose,
          shape: AnimalShape.hippo,
          mirrored: mirrored,
          color: const Color(0xFF6E8FAE),
          surface: const Color(0xFFFFFFFF),
          ink: const Color(0xFF000000),
        ).paint(Canvas(recorder), const Size(158, 112));
        final image = await recorder.endRecording().toImage(158, 112);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        pose.dispose();
        return data!.buffer.asUint8List();
      }

      late Uint8List facingLeft;
      late Uint8List facingRight;
      await tester.runAsync(() async {
        facingLeft = await render(mirrored: false);
        facingRight = await render(mirrored: true);
      });

      expect(facingRight, isNot(equals(facingLeft)));
    });

    testWidgets('"reduce motion" freezes the face rather than slowing it (FR-033a)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _avatar(state: CharacterVisualState.speaking, disableAnimations: true),
      );

      final driver = tester.widget<TalkPoseDriver>(find.byType(TalkPoseDriver));
      expect(driver.animate, isFalse);
    });

    testWidgets('passes the reply\'s own intensity down as the amplitude', (tester) async {
      await tester.pumpWidget(_avatar(state: CharacterVisualState.speaking, intensity: 0.4));

      expect(tester.widget<TalkPoseDriver>(find.byType(TalkPoseDriver)).intensity, 0.4);

      // A talking seat leaves a ticker running; settle it before the test
      // ends.
      await tester.pumpWidget(_avatar(state: CharacterVisualState.idle));
      await tester.pumpAndSettle();
    });

    testWidgets('the drawn glyph is not announced — the label stays name plus state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_avatar(state: CharacterVisualState.idle));

      final semantics = tester.getSemantics(find.byType(CharacterAvatar));
      expect(semantics.label, startsWith('Кот, '));
      expect(semantics.label, isNot(contains('🐱')));

      handle.dispose();
    });
  });

  group('TalkPoseDriver', () {
    testWidgets('a speaking seat keeps moving', (tester) async {
      final poses = await _pumpDriver(tester, state: CharacterVisualState.speaking);
      // Long enough to span several syllable slots: a couple of silent
      // ones in a row is normal speech, not a frozen face.
      final seen = await _collect(tester, poses, 40);
      await _settleDriver(tester);

      expect(seen.toSet().length, greaterThan(1));
      expect(seen.any((pose) => pose.mouthOpen > 0), isTrue);
    });

    testWidgets('an idle seat schedules no frames at all', (tester) async {
      final poses = await _pumpDriver(tester, state: CharacterVisualState.idle);

      // Regression guard for the whole widget suite, not just this seat: a
      // permanently ticking avatar makes `pumpAndSettle()` time out in
      // every test that renders the table.
      await tester.pumpAndSettle();
      expect(poses.value, TalkPose.still);
    });

    testWidgets('with animations disabled it holds the still pose', (tester) async {
      final poses = await _pumpDriver(
        tester,
        state: CharacterVisualState.speaking,
        animate: false,
      );

      await tester.pumpAndSettle();
      expect(poses.value, TalkPose.still);
    });

    testWidgets('starts moving when a seat begins to speak', (tester) async {
      final poses = await _pumpDriver(tester, state: CharacterVisualState.idle);
      await tester.pumpAndSettle();

      await _pumpDriver(tester, state: CharacterVisualState.speaking);
      final seen = await _collect(tester, poses, 12);
      await _settleDriver(tester);

      expect(seen.toSet().length, greaterThan(1));
    });

    testWidgets('the answered reaction runs once and then stops itself', (tester) async {
      final poses = await _pumpDriver(tester, state: CharacterVisualState.answered);
      final during = await _collect(tester, poses, 6);

      expect(during.any((pose) => pose.scale > 1), isTrue);

      // Settles on its own: no loop, no timer to cancel.
      await tester.pumpAndSettle();
      expect(poses.value, TalkPose.still);
    });
  });
}
