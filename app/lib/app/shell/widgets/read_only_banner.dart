import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';

/// Persistent banner shown on every shell tab while `StorageMode.readOnly`
/// — the user chose "continue without saving" (FR-021d, FR-021e). Stays
/// visible until `retry()` succeeds and the app-scoped
/// `StorageRecoveryCubit` moves out of `readOnlyAccepted` (FR-021e1).
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, color: colors.onErrorContainer, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.readOnlyBannerText,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: () => context.read<StorageRecoveryCubit>().retry(),
                child: Text(l10n.readOnlyBannerRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
