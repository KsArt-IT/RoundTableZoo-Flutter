import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:roundtablezoo/app/shell/widgets/read_only_banner.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';

/// The app shell: bottom navigation over the three branches of
/// `StatefulShellRoute.indexedStack`. Branch state survives tab switches —
/// the shell itself never rebuilds (FR-002, FR-004, SC-002).
class ShellPage extends StatelessWidget {
  const ShellPage({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Column(
        children: [
          BlocBuilder<StorageRecoveryCubit, StorageRecoveryState>(
            buildWhen: (previous, current) =>
                previous is StorageRecoveryReadOnlyAccepted || current is StorageRecoveryReadOnlyAccepted,
            builder: (context, state) =>
                state is StorageRecoveryReadOnlyAccepted ? const ReadOnlyBanner() : const SizedBox.shrink(),
          ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.table_restaurant_outlined),
            selectedIcon: const Icon(Icons.table_restaurant),
            label: l10n.sectionTable,
            tooltip: l10n.sectionTable,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: l10n.sectionDiary,
            tooltip: l10n.sectionDiary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.sectionSettings,
            tooltip: l10n.sectionSettings,
          ),
        ],
      ),
    );
  }
}
