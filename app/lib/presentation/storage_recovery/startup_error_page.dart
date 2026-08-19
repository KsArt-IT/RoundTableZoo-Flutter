import 'package:flutter/material.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/theme/app_theme.dart';
import 'package:roundtablezoo/core/utils/locale_resolution.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// Shown instead of `AppRoot` when a non-storage startup step fails —
/// `TimeZones.initialize()` or `configureDependencies()` throwing before
/// `main.dart` even reaches `AppBootstrap.start()` (FR-018a). This is
/// deliberately its own top-level `MaterialApp`, not a go_router
/// destination like `StorageRecoveryPage`: DI and the router don't exist
/// yet at this point, so nothing here may depend on them.
class StartupErrorPage extends StatelessWidget {
  const StartupErrorPage({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Same system-language-with-Russian-fallback rule as everywhere else
      // pre-settings (FR-021b1, FR-029) — settings aren't reachable here.
      localeResolutionCallback: resolveDeviceLocale,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      l10n.startupErrorTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.startupErrorBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    Semantics(
                      button: true,
                      label: l10n.startupErrorRetry,
                      child: SizedBox(
                        height: AppConstants.minTapTargetDp,
                        child: FilledButton(
                          onPressed: onRetry,
                          child: Text(l10n.startupErrorRetry),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
