import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/settings/cubit/settings_cubit.dart';

/// Character-voicing sound toggle (FR-026). Unrelated to the reminder
/// notification's sound — the hint text says so explicitly (FR-016c).
class SoundSection extends StatelessWidget {
  const SoundSection({required this.enabled, required this.controlsEnabled, super.key});

  final bool enabled;
  final bool controlsEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // SwitchListTile already encodes on/off via the thumb position and
    // announces it through its built-in `toggled` semantic — no extra
    // wrapper needed (FR-027, FR-028).
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppConstants.minTapTargetDp),
      child: SwitchListTile(
        title: Text(l10n.settingsSound),
        subtitle: Text(l10n.settingsSoundHint),
        value: enabled,
        onChanged: controlsEnabled
            ? (value) => unawaited(context.read<SettingsCubit>().setSoundEnabled(value: value))
            : null,
      ),
    );
  }
}
