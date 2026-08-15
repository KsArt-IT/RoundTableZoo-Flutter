import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:roundtablezoo/core/theme/app_theme.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// `MaterialApp.router` shell: theme, localization, and the go_router
/// config. `themeMode`/`locale` are `system` here — Phase 7 wires them to
/// `AppSettingsCubit` (FR-027, FR-029, US5.3).
class AppMaterialRouter extends StatelessWidget {
  const AppMaterialRouter({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Unsupported device language falls back to Russian, the template
      // locale (FR-029, US5.3).
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale == null) return const Locale('ru');
        for (final locale in supportedLocales) {
          if (locale.languageCode == deviceLocale.languageCode) return locale;
        }
        return const Locale('ru');
      },
      routerConfig: router,
    );
  }
}
