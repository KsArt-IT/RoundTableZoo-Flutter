import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/table/widgets/character_avatar.dart';

const _character = Character(
  id: 'cat',
  name: 'Кот',
  colorHex: 0xFF8A7CA8,
  fallbackReply: 'Мр-р.',
  maxReplyLength: 220,
  idleAnimation: 'assets/lottie/cat_idle.json',
  talkAnimation: 'assets/lottie/cat_talk.json',
);

Widget _wrapped({required CharacterVisualState state, bool disableAnimations = false}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: CharacterAvatar(character: _character, state: state, onTap: null),
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
}
