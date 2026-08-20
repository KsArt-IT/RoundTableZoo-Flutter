import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// The four states a seat at the table can be in (FR-011). Distinguished
/// by more than the idle/talk animation swap alone — `CharacterAvatar`
/// also changes the semantics label and, for `answered`, adds a badge
/// (FR-012: not color alone).
enum CharacterVisualState { idle, waiting, speaking, answered }

/// One character's seat. Renders its Lottie animation when the asset
/// exists, otherwise a static colored circle showing the character's
/// `emoji` — or, failing that, the first letter of its name. Both static
/// forms are standing branches, not placeholders for missing test fixtures
/// (`contracts/character-config.md` §5).
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    required this.character,
    required this.state,
    required this.onTap,
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
                    ClipOval(child: _visual(context, AppConstants.characterAvatarDp)),
                    if (state == CharacterVisualState.waiting)
                      const Positioned(
                        bottom: 4,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    if (state == CharacterVisualState.answered)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          size: 16,
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
    if (asset == null) return _staticAvatar(context, size);

    // FR-033a: "reduce motion" freezes idle/talk animations too, not just
    // `SpeakingBubble`'s reveal effect — a still frame, not a moving loop.
    return Lottie.asset(
      asset,
      fit: BoxFit.cover,
      animate: !MediaQuery.disableAnimationsOf(context),
      errorBuilder: (context, error, stackTrace) => _staticAvatar(context, size),
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
      child: Text(
        emoji,
        // Scales with the seat instead of a fixed point size, so the glyph
        // keeps its proportion if `minTapTargetDp` ever changes.
        style: TextStyle(fontSize: size * _emojiSizeRatio),
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
