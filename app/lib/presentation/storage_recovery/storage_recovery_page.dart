import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';

/// Shown instead of the shell when `StorageMode.unavailable` (FR-021b).
/// Reached before settings can be read, so it always uses the system
/// theme/language (FR-021b1) — never a hand-rolled unstyled fallback.
///
/// Reads `StorageRecoveryCubit` from an ancestor provider — it's a
/// long-lived, app-scoped Cubit (registered in `AppRoot`), the same
/// instance the read-only banner drives `retry()` on (FR-021e1).
class StorageRecoveryPage extends StatelessWidget {
  const StorageRecoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<StorageRecoveryCubit, StorageRecoveryState>(
          builder: (context, state) {
            final isWorking = state is StorageRecoveryWorking;
            final cause = switch (state) {
              StorageRecoveryIdle(:final cause) => cause,
              StorageRecoveryError(:final failure) => failure,
              _ => null,
            };

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.storage_outlined, size: 64, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    l10n.storageRecoveryTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (cause != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      cause.localizedMessage(l10n),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (isWorking)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    _RecoveryButton(
                      label: l10n.storageRecoveryRetry,
                      onPressed: () => context.read<StorageRecoveryCubit>().retry(),
                    ),
                    const SizedBox(height: 12),
                    _RecoveryButton(
                      label: l10n.storageRecoveryResetData,
                      isDestructive: true,
                      onPressed: () => _confirmReset(context, l10n),
                    ),
                    const SizedBox(height: 12),
                    _RecoveryButton(
                      label: l10n.storageRecoveryContinueWithoutSaving,
                      onPressed: () => context.read<StorageRecoveryCubit>().continueWithoutSaving(),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, AppLocalizations l10n) async {
    final cubit = context.read<StorageRecoveryCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.storageRecoveryResetConfirmTitle),
        content: Text(l10n.storageRecoveryResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.storageRecoveryResetConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.storageRecoveryResetConfirmConfirm,
              style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      unawaited(cubit.resetData());
    }
  }
}

class _RecoveryButton extends StatelessWidget {
  const _RecoveryButton({required this.label, required this.onPressed, this.isDestructive = false});

  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: AppConstants.minTapTargetDp,
        child: isDestructive
            ? OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                child: Text(label),
              )
            : FilledButton(onPressed: onPressed, child: Text(label)),
      ),
    );
  }
}
