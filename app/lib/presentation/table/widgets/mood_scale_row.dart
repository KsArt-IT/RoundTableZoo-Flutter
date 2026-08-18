import 'package:flutter/material.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/constants/mood_scale.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// Five-emoji mood scale (FR-001, FR-013). The selected value is marked by
/// shape and color together, not color alone. Each option is a bespoke
/// tappable widget — not a Material list tile — so it carries its own
/// `Semantics` directly, with no merge-boundary trap
/// (`project/process/lessons-learned.md`).
///
/// [onSelected] is `null` in read-only mode: options render but don't
/// respond to taps (FR-032) — nothing pretends to save.
class MoodScaleRow extends StatelessWidget {
  const MoodScaleRow({required this.selected, required this.onSelected, super.key});

  final MoodScale? selected;
  final ValueChanged<MoodScale>? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final option in MoodScale.values)
          _MoodOption(
            option: option,
            label: option.label(l10n),
            isSelected: option == selected,
            onTap: onSelected == null ? null : () => onSelected!(option),
          ),
      ],
    );
  }
}

class _MoodOption extends StatelessWidget {
  const _MoodOption({
    required this.option,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final MoodScale option;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: AppConstants.minTapTargetDp,
        child: Container(
          width: AppConstants.minTapTargetDp,
          height: AppConstants.minTapTargetDp,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? option.color.withValues(alpha: 0.3) : Colors.transparent,
            border: Border.all(
              color: isSelected ? option.color : colors.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ExcludeSemantics(child: Text(option.emoji, style: const TextStyle(fontSize: 28))),
        ),
      ),
    );
  }
}
