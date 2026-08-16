import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:roundtablezoo/app/router/app_routes.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/di/storage_di_switch.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/failure_toast_gate.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/app_settings_cubit.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/app_settings_state.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';
import 'package:toastification/toastification.dart';

/// The single place that reacts to global Cubit state: shows a deduplicated
/// toast for `*State.error(failure)` (FR-021, FR-021f) — from
/// `StorageRecoveryCubit` or `AppSettingsCubit` — and swaps the
/// storage-backed DI graph when `StorageRecoveryCubit` reaches
/// `recovered`/`readOnlyAccepted` (FR-021c1, FR-021e1). Must sit inside the
/// routed tree (`MaterialApp.router`'s `builder`) so `GoRouterState.of` and
/// `AppLocalizations.of` are available.
class RootBlocListener extends StatelessWidget {
  const RootBlocListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<StorageRecoveryCubit, StorageRecoveryState>(
          listener: _handleStorageRecoveryState,
        ),
        BlocListener<AppSettingsCubit, AppSettingsState>(listener: _handleAppSettingsState),
      ],
      child: child,
    );
  }

  void _handleStorageRecoveryState(BuildContext context, StorageRecoveryState state) {
    switch (state) {
      case StorageRecoveryRecovered(:final database):
        StorageDiSwitch.usePersistentStorage(database);
      case StorageRecoveryReadOnlyAccepted():
        StorageDiSwitch.useReadOnlyStorage();
      case StorageRecoveryError(:final failure):
        _maybeShowToast(context, failure);
      case StorageRecoveryIdle() || StorageRecoveryWorking():
        break;
    }
  }

  void _handleAppSettingsState(BuildContext context, AppSettingsState state) {
    if (state case AppSettingsError(:final failure)) _maybeShowToast(context, failure);
  }

  void _maybeShowToast(BuildContext context, AppFailure failure) {
    // The recovery screen already shows the reason on its own surface —
    // no duplicate toast on top of it.
    if (GoRouterState.of(context).matchedLocation == AppRoutes.storageErrorPath) return;
    if (!getIt<FailureToastGate>().shouldShow(failure)) return;

    final l10n = AppLocalizations.of(context);
    toastification.show(
      context: context,
      type: ToastificationType.error,
      title: Text(failure.localizedMessage(l10n)),
      autoCloseDuration: const Duration(seconds: 4),
    );
  }
}
