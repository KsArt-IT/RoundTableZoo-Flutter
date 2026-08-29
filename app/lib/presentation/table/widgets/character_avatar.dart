import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/constants/app_dimens.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/domain/value_objects/face_shape.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/table/widgets/cat_face_painter.dart';
import 'package:roundtablezoo/presentation/table/widgets/character_visual_state.dart';
import 'package:roundtablezoo/presentation/table/widgets/talk_pose_driver.dart';

export 'package:roundtablezoo/presentation/table/widgets/character_visual_state.dart';

/// One character's seat. Three renderers, in order: the character's Lottie
/// animation when the asset exists; the vector face drawn by
/// `CatFacePainter` when the character declares a [FaceShape]; otherwise a
/// static colored circle showing the character's `emoji` — or, failing
/// that, the first letter of its name. The static forms are standing
/// branches, not placeholders for missing test fixtures
/// (`contracts/character-config.md` §5).
///
/// The seat is also where `CharacterVisualState` stops being a state and
/// becomes movement: nothing above this widget knows how a character is
/// drawn, which is what keeps swapping the animation technique a
/// one-widget change (`project/architecture/character-animation.md`).
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    required this.character,
    required this.state,
    required this.onTap,
    this.intensity = 1.0,
    super.key,
  });

  /// How far the character color is faded toward the surface behind an
  /// emoji, how thick the identity ring around it is, and the glyph's size
  /// as a fraction of the seat. Local to this widget — they describe one
  /// avatar's look, not an app-wide design token.
  static const double _emojiFillFade = 0.72;
  static const double _emojiRingWidth = 2;
  static const double _emojiSizeRatio = 0.5;

  final Character character;
  final CharacterVisualState state;

  /// Amplitude of the speaking animation — `CharacterReaction.intensity`,
  /// 0..1, straight from the reply this seat is voicing. Ignored by the
  /// states that aren't speaking, and by seats without a drawn face.
  final double intensity;

  /// `null` disables the tap — FR-014's precondition, decided by the
  /// caller (`TablePage`), not this widget.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: '${character.name}, ${_stateLabel(l10n)}',
      // Ink splashes paint into the nearest enclosing `Material`, not into
      // the tapped widget. Without this local one the nearest `Material`
      // is the `Scaffold`'s, which sits *below* `RoundTableLayout`'s table
      // surface `CustomPaint` — so the halo was drawn and then covered by
      // the table. A transparent `Material` inside the seat gives the ink
      // a surface above the table instead.
      child: Material(
        type: MaterialType.transparency,
        // `InkWell` (not a plain `GestureDetector`) so a seat is reachable
        // by keyboard `Tab` traversal, same idiom as `MoodScaleRow`'s
        // `_MoodOption` (FR-035).
        //
        // `InkWell`, not `InkResponse`, specifically for `customBorder`:
        // Flutter only clips ink features when the well is *contained*
        // (`InkSplash` builds its clip callback solely in that case, and
        // `paintInkCircle` applies `customBorder` only when that callback
        // exists). On a bare `InkResponse` the property is silently
        // ignored and the ripple keeps the square geometry of the box.
        // `InkWell` is `InkResponse(containedInkWell: true)`, so the
        // circle actually takes effect — and keyboard focus behaves the
        // same, since it is the same class.
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            // The seat's full footprint. The avatar below is deliberately
            // smaller, so the ripple has a ring of its own to expand into
            // instead of hiding entirely behind the disc.
            width: AppConstants.characterSeatDp,
            height: AppConstants.characterSeatDp,
            child: Center(
              child: SizedBox(
                width: AppConstants.characterAvatarDp,
                height: AppConstants.characterAvatarDp,
                // Badges anchor to the drawn disc, not to the seat —
                // otherwise they would float out in the halo margin.
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _visual(context, AppConstants.characterAvatarDp),
                    if (state == CharacterVisualState.waiting)
                      const Positioned(
                        bottom: 4,
                        child: SizedBox(
                          width: AppDimens.iconSizeSmall,
                          height: AppDimens.iconSizeSmall,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    if (state == CharacterVisualState.answered)
                      // Top corner, not bottom: the drawn animal is wider
                      // than tall and sits centered, so the box's spare
                      // room is the strip above and below it. Anchored at
                      // the bottom the badge floated under the cat's paws
                      // with nothing to belong to — up here it reads as a
                      // marker over the character, the way a speech mark
                      // should.
                      Positioned(
                        right: 0,
                        top: 4,
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          size: AppDimens.iconSizeSmall,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _visual(BuildContext context, double size) {
    final asset = state == CharacterVisualState.speaking
        ? character.talkAnimation
        : character.idleAnimation;
    if (asset == null) {
      final face = character.face;
      // The drawn cat lies on its side: its tail and forepaws reach past
      // the disc the emoji avatar lives in, so it is the one branch that
      // is *not* clipped to a circle.
      return face == null
          ? ClipOval(child: _staticAvatar(context, size))
          : _drawnFace(context, size, face);
    }

    // FR-033a: "reduce motion" freezes idle/talk animations too, not just
    // `SpeakingBubble`'s reveal effect — a still frame, not a moving loop.
    return ClipOval(
      child: Lottie.asset(
        asset,
        fit: BoxFit.cover,
        animate: !MediaQuery.disableAnimationsOf(context),
        errorBuilder: (context, error, stackTrace) => _staticAvatar(context, size),
      ),
    );
  }

  Widget _drawnFace(BuildContext context, double size, FaceShape face) {
    final scheme = Theme.of(context).colorScheme;

    return TalkPoseDriver(
      state: state,
      intensity: intensity,
      // Per character, so two animals speaking at once don't share a
      // syllable beat — `hashCode` of a `String` is stable within a run,
      // which is all a decorrelation seed needs.
      seed: character.id.hashCode,
      // FR-033a: "reduce motion" is a still frame, not a slower loop.
      animate: !MediaQuery.disableAnimationsOf(context),
      builder: (context, pose) => CustomPaint(
        // A childless `CustomPaint` takes its size from this argument and
        // otherwise collapses to `Size.zero`, because a non-positioned
        // `Stack` child is laid out with *loose* constraints. Without it
        // the cat is built, ticks, and paints nothing at all.
        size: Size.square(size),
        painter: switch (face) {
          FaceShape.cat => CatFacePainter(
            pose: pose,
            color: Color(character.colorHex),
            surface: scheme.surface,
            ink: scheme.onSurface,
          ),
        },
      ),
    );
  }

  Widget _staticAvatar(BuildContext context, double size) {
    final color = Color(character.colorHex);
    final emoji = character.emoji;

    // No emoji configured: the original first-letter avatar, unchanged —
    // white on the full character color.
    if (emoji == null) {
      return Container(
        color: color,
        alignment: Alignment.center,
        child: Text(
          character.name.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      );
    }

    // Emoji glyphs carry their own colors, so the full character color
    // behind them fights for attention (and a green crocodile on a green
    // disc all but disappears). Fade the fill toward the surface and keep
    // the identity color as a ring instead — readable in both themes.
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(color, Theme.of(context).colorScheme.surface, _emojiFillFade),
        border: Border.all(color: color, width: _emojiRingWidth),
      ),
      alignment: Alignment.center,
      // `Text` auto-generates a semantics node carrying the glyph as its
      // label, which the outer `Semantics` merges into its own — leaking
      // the unpronounceable emoji into the announced label. It's decorative
      // (state is already conveyed by the label text), so exclude it.
      child: ExcludeSemantics(
        child: Text(
          emoji,
          // Scales with the seat instead of a fixed point size, so the glyph
          // keeps its proportion if `minTapTargetDp` ever changes.
          style: TextStyle(fontSize: size * _emojiSizeRatio),
        ),
      ),
    );
  }

  String _stateLabel(AppLocalizations l10n) => switch (state) {
    CharacterVisualState.idle => l10n.tableCharacterStateIdle,
    CharacterVisualState.waiting => l10n.tableCharacterStateWaiting,
    CharacterVisualState.speaking => l10n.tableCharacterStateSpeaking,
    CharacterVisualState.answered => l10n.tableCharacterStateAnswered,
  };
}
