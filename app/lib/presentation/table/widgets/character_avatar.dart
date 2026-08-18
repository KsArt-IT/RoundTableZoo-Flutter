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
/// exists, otherwise a static colored circle with the character's first
/// letter — a standing branch, not a placeholder for missing test fixtures
/// (`contracts/character-config.md` §5).
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({required this.character, required this.state, required this.onTap, super.key});

  final Character character;
  final CharacterVisualState state;

  /// `null` disables the tap — FR-014's precondition, decided by the
  /// caller (`TablePage`), not this widget.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const size = AppConstants.minTapTargetDp * 1.5;

    return Semantics(
      button: true,
      label: '${character.name}, ${_stateLabel(l10n)}',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(child: _visual()),
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
    );
  }

  Widget _visual() {
    final asset = state == CharacterVisualState.speaking ? character.talkAnimation : character.idleAnimation;
    if (asset == null) return _staticAvatar();

    return Lottie.asset(
      asset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _staticAvatar(),
    );
  }

  Widget _staticAvatar() => Container(
    color: Color(character.colorHex),
    alignment: Alignment.center,
    child: Text(
      character.name.substring(0, 1).toUpperCase(),
      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
    ),
  );

  String _stateLabel(AppLocalizations l10n) => switch (state) {
    CharacterVisualState.idle => l10n.tableCharacterStateIdle,
    CharacterVisualState.waiting => l10n.tableCharacterStateWaiting,
    CharacterVisualState.speaking => l10n.tableCharacterStateSpeaking,
    CharacterVisualState.answered => l10n.tableCharacterStateAnswered,
  };
}
