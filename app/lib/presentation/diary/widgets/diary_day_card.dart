import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/constants/mood_scale.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/diary/cubit/diary_state.dart';
import 'package:roundtablezoo/presentation/diary/widgets/diary_reactions_list.dart';

/// One history card: date, mood emoji and day text. A single tap-target
/// expands/collapses both the full day text and its character reactions
/// together — one disclosure per card, not two (FR-014, Clarifications,
/// research.md R7).
class DiaryDayCard extends StatelessWidget {
  const DiaryDayCard({
    required this.day,
    required this.characters,
    required this.onToggle,
    super.key,
  });

  final DiaryDay day;
  final Map<String, Character> characters;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scale = MoodScale.fromValue(day.entry.moodScore.value);
    final dateText = DateFormat.yMMMMd(
      l10n.localeName,
    ).format(DateTime(day.day.year, day.day.month, day.day.day));
    final text = day.entry.dayText;
    final expanded = day.expanded;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Semantics(
        // FR-030: announces "expanded"/"collapsed" alongside the label —
        // one flag, following the single disclosure this card has.
        expanded: expanded,
        child: InkWell(
          onTap: onToggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppConstants.minTapTargetDp),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scale.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dateText, style: Theme.of(context).textTheme.titleMedium),
                            if (text != null && text.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                text,
                                maxLines: expanded ? null : 3,
                                overflow: expanded ? null : TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (expanded) ...[
                    const Divider(height: 20),
                    if (day.reactionsLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      DiaryReactionsList(
                        reactions: day.reactions ?? const [],
                        characters: characters,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
