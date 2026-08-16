import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/notifications/notification_permission_status.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/settings/cubit/settings_cubit.dart';

/// Reminder toggle, time picker, and permission warning (FR-012, FR-013,
/// FR-013a, FR-021).
class ReminderSection extends StatelessWidget {
  const ReminderSection({
    required this.enabled,
    required this.time,
    required this.permission,
    required this.controlsEnabled,
    super.key,
  });

  final bool enabled;
  final ReminderTime time;
  final NotificationPermissionStatus permission;
  final bool controlsEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SettingsCubit>();
    final timeOfDay = TimeOfDay(hour: time.hour, minute: time.minute);
    final formattedTime = MaterialLocalizations.of(context).formatTimeOfDay(timeOfDay);
    final timePickerEnabled = enabled && controlsEnabled;
    final showWarning = enabled && permission == NotificationPermissionStatus.denied;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(l10n.settingsReminder, style: Theme.of(context).textTheme.titleMedium),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppConstants.minTapTargetDp),
          child: SwitchListTile(
            title: Text(l10n.settingsReminderEnabled),
            value: enabled,
            onChanged: controlsEnabled
                ? (value) => unawaited(cubit.setReminderEnabled(value: value))
                : null,
          ),
        ),
        // Announced as a time, not a pair of numbers (FR-028a).
        Semantics(
          label: '${l10n.settingsReminderTime}: $formattedTime',
          button: true,
          enabled: timePickerEnabled,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppConstants.minTapTargetDp),
            child: ListTile(
              title: ExcludeSemantics(child: Text(l10n.settingsReminderTime)),
              trailing: ExcludeSemantics(child: Text(formattedTime)),
              enabled: timePickerEnabled,
              onTap: () => unawaited(_pickTime(context, cubit, timeOfDay)),
            ),
          ),
        ),
        if (showWarning) _PermissionWarning(cubit: cubit, l10n: l10n),
      ],
    );
  }

  Future<void> _pickTime(BuildContext context, SettingsCubit cubit, TimeOfDay initial) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final value = ReminderTime.create(
      hour: picked.hour,
      minute: picked.minute,
    ).valueOrGet(() => time);
    await cubit.setReminderTime(value);
  }
}

class _PermissionWarning extends StatelessWidget {
  const _PermissionWarning({required this.cubit, required this.l10n});

  final SettingsCubit cubit;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        color: colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsReminderPermissionDenied(l10n.appTitle),
                style: TextStyle(color: colors.onErrorContainer),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppConstants.minTapTargetDp),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => unawaited(cubit.openNotificationSettings()),
                    child: Text(l10n.settingsOpenSystemSettings),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
