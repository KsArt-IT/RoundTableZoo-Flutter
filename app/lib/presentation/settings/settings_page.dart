import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/notifications/notification_permission_status.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/settings/cubit/settings_cubit.dart';
import 'package:roundtablezoo/presentation/settings/cubit/settings_state.dart';
import 'package:roundtablezoo/presentation/settings/widgets/ai_disclosure_section.dart';
import 'package:roundtablezoo/presentation/settings/widgets/language_section.dart';
import 'package:roundtablezoo/presentation/settings/widgets/reminder_section.dart';
import 'package:roundtablezoo/presentation/settings/widgets/sound_section.dart';
import 'package:roundtablezoo/presentation/settings/widgets/theme_section.dart';
import 'package:toastification/toastification.dart';

/// The `/settings` screen: appearance, language, reminder, sound. Every
/// section renders in its final layout from the first frame — `loading`
/// only disables controls, it never swaps in a spinner or blank state
/// (FR-004), so nothing shifts position when data arrives.
///
/// Owns a fresh, screen-scoped `SettingsCubit` (research.md, R9) rather
/// than reading one from an ancestor provider — created here, closed on
/// `dispose`. A `WidgetsBindingObserver` re-checks the notification
/// permission on resume, so returning from system settings clears the
/// warning without re-flipping the toggle (FR-022).
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  late final SettingsCubit _cubit = getIt<SettingsCubit>();
  StreamSubscription<AppFailure>? _failureSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _failureSubscription = _cubit.failures.listen(_showFailureToast);
  }

  void _showFailureToast(AppFailure failure) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    toastification.show(
      context: context,
      type: ToastificationType.error,
      title: Text(failure.localizedMessage(l10n)),
      autoCloseDuration: const Duration(seconds: 4),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_cubit.refreshPermissionStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_failureSubscription?.cancel());
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final l10n = AppLocalizations.of(context);
          final loaded = state is SettingsLoaded ? state : null;
          final settings = loaded?.settings;
          final controlsEnabled = loaded != null;

          return Scaffold(
            appBar: AppBar(title: Text(l10n.sectionSettings)),
            body: SafeArea(
              child: ListView(
                children: [
                  ThemeSection(
                    current: settings?.themeMode ?? ThemePreference.system,
                    enabled: controlsEnabled,
                  ),
                  const Divider(height: 1),
                  LanguageSection(
                    current: settings?.locale ?? LocalePreference.system,
                    enabled: controlsEnabled,
                  ),
                  const Divider(height: 1),
                  ReminderSection(
                    enabled: settings?.reminderEnabled ?? false,
                    time: settings?.reminderTime ?? ReminderTime.defaultValue,
                    permission: loaded?.permission ?? NotificationPermissionStatus.unknown,
                    controlsEnabled: controlsEnabled,
                  ),
                  const Divider(height: 1),
                  SoundSection(
                    enabled: settings?.soundEnabled ?? true,
                    controlsEnabled: controlsEnabled,
                  ),
                  const Divider(height: 1),
                  const AiDisclosureSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
