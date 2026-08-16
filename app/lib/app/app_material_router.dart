import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:roundtablezoo/app/root_bloc_listener.dart';
import 'package:roundtablezoo/core/theme/app_theme.dart';
import 'package:roundtablezoo/core/utils/locale_resolution.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/app_settings_cubit.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/app_settings_state.dart';
import 'package:toastification/toastification.dart';

/// `MaterialApp.router` shell: theme, localization, and the go_router
/// config. `themeMode`/`locale` follow `AppSettingsCubit`; its `initial`/
/// `error` states resolve to system theme and system/RU locale, same as a
/// `loaded` state with `system` preferences (FR-027, FR-029, US5.3).
class AppMaterialRouter extends StatelessWidget {
  const AppMaterialRouter({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      // Only themeMode/locale are read below — an unrelated settings write
      // (enabledCharacterIds, dayStartHour, ...) would otherwise still
      // rebuild the whole MaterialApp.router, since UserSettings is a
      // @freezed value class and every field participates in equality.
      buildWhen: (previous, current) =>
          previous.themeMode != current.themeMode || previous.locale != current.locale,
      builder: (context, settingsState) {
        return ToastificationWrapper(
          child: MaterialApp.router(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settingsState.themeMode,
            locale: settingsState.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Only consulted when `locale` above is null (system
            // preference).
            localeResolutionCallback: resolveDeviceLocale,
            // Inside the routed tree so RootBlocListener can read
            // GoRouterState/AppLocalizations (app/root_bloc_listener.dart).
            builder: (context, child) => RootBlocListener(child: child ?? const SizedBox.shrink()),
            routerConfig: router,
          ),
        );
      },
    );
  }
}
