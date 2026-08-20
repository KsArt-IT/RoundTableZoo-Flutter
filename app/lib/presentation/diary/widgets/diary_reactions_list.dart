import 'package:flutter/material.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// All saved reactions for one expanded day, in `createdAt ASC` order —
/// including repeated replies from the same character (FR-015). Captioned
/// by character name, falling back to the raw `characterId` when the
/// character has since been removed from the catalog (FR-016, FR-019,
/// research.md R8).
class DiaryReactionsList extends StatelessWidget {
  const DiaryReactionsList({required this.reactions, required this.characters, super.key});

  final List<CharacterReaction> reactions;
  final Map<String, Character> characters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (reactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(l10n.diaryNoReactions, style: Theme.of(context).textTheme.bodySmall),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final reaction in reactions)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Semantics(
              label: _semanticsLabel(l10n, reaction, characters[reaction.characterId]),
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reaction.isFallback) ...[
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  '${characters[reaction.characterId]?.name ?? reaction.characterId}: ',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: reaction.reply),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _semanticsLabel(AppLocalizations l10n, CharacterReaction reaction, Character? character) {
    final name = character?.name ?? reaction.characterId;
    final parts = ['$name: ${reaction.reply}'];
    if (reaction.isFallback) parts.add(l10n.tableReplyFallbackLabel);
    return parts.join('. ');
  }
}
