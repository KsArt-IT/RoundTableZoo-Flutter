import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/settings/cubit/settings_cubit.dart';

/// Theme choice (FR-005…FR-007). Selection is shown by the radio dot, not
/// color alone (FR-028), and each row is `Semantics`-labeled with its
/// current value (FR-028a).
class ThemeSection extends StatelessWidget {
  const ThemeSection({required this.current, required this.enabled, super.key});

  final ThemePreference current;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return RadioGroup<ThemePreference>(
      groupValue: current,
      onChanged: enabled
          ? (value) {
              if (value != null) unawaited(context.read<SettingsCubit>().setThemeMode(value));
            }
          : (_) {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(l10n.settingsAppearance, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final option in ThemePreference.values)
            _ThemeOption(value: option, label: _labelFor(l10n, option), enabled: enabled),
        ],
      ),
    );
  }

  String _labelFor(AppLocalizations l10n, ThemePreference value) => switch (value) {
    ThemePreference.light => l10n.settingsThemeLight,
    ThemePreference.dark => l10n.settingsThemeDark,
    ThemePreference.system => l10n.settingsThemeSystem,
  };
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.value, required this.label, required this.enabled});

  final ThemePreference value;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // RadioListTile already builds accessible semantics from its `title`
    // (the label) plus the radio's own selected state — a second wrapping
    // `Semantics` would sit above RadioListTile's internal merge boundary
    // and never reach the tappable node the accessibility guidelines
    // inspect (FR-027, FR-028).
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppConstants.minTapTargetDp),
      child: RadioListTile<ThemePreference>(value: value, enabled: enabled, title: Text(label)),
    );
  }
}
