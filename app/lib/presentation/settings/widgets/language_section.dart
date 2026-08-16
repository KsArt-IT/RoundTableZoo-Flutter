import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/settings/cubit/settings_cubit.dart';

/// Each language's name is a constant written in that language itself, not
/// a translated string (FR-011) — a Russian speaker still reads
/// "Українська"/"English" in Cyrillic/Latin, not machine-translated.
const Map<LocalePreference, String> _languageNames = {
  LocalePreference.ru: 'Русский',
  LocalePreference.uk: 'Українська',
  LocalePreference.en: 'English',
};

/// Language choice (FR-008…FR-011). "System" stays checked even when the
/// device language isn't supported (FR-010) — this only reflects
/// `current`, it never re-derives the device locale itself.
class LanguageSection extends StatelessWidget {
  const LanguageSection({required this.current, required this.enabled, super.key});

  final LocalePreference current;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return RadioGroup<LocalePreference>(
      groupValue: current,
      onChanged: enabled
          ? (value) {
              if (value != null) unawaited(context.read<SettingsCubit>().setLocale(value));
            }
          : (_) {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(l10n.settingsLanguage, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final option in LocalePreference.values)
            _LanguageOption(
              value: option,
              label: option == LocalePreference.system
                  ? l10n.settingsLanguageSystem
                  : _languageNames[option]!,
              enabled: enabled,
            ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.value, required this.label, required this.enabled});

  final LocalePreference value;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // See theme_section.dart's `_ThemeOption` — RadioListTile builds its
    // own accessible semantics from `title`, so no wrapping `Semantics` is
    // needed (FR-027, FR-028).
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppConstants.minTapTargetDp),
      child: RadioListTile<LocalePreference>(value: value, enabled: enabled, title: Text(label)),
    );
  }
}
