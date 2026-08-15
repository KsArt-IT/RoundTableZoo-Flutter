import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:roundtablezoo/app/app_material_router.dart';
import 'package:roundtablezoo/app/router/app_router.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';

/// Application entry widget. [storageRecoveryCubit] is app-scoped and
/// already carries the outcome of the startup `AppBootstrap.start()` probe
/// (`main.dart`) — the shell, the recovery screen, and the read-only banner
/// all read from this one instance.
///
/// Further global `BlocProvider`s (settings, current day) join here in
/// later phases (US4, US5).
class AppRoot extends StatelessWidget {
  const AppRoot({required this.storageRecoveryCubit, super.key});

  final StorageRecoveryCubit storageRecoveryCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: storageRecoveryCubit,
      child: _RoutedApp(storageRecoveryCubit: storageRecoveryCubit),
    );
  }
}

class _RoutedApp extends StatefulWidget {
  const _RoutedApp({required this.storageRecoveryCubit});

  final StorageRecoveryCubit storageRecoveryCubit;

  @override
  State<_RoutedApp> createState() => _RoutedAppState();
}

class _RoutedAppState extends State<_RoutedApp> {
  late final CubitRefreshListenable _refreshListenable = CubitRefreshListenable(
    widget.storageRecoveryCubit.stream,
  );
  late final GoRouter _router = buildAppRouter(
    storageRecoveryCubit: widget.storageRecoveryCubit,
    refreshListenable: _refreshListenable,
  );

  @override
  Widget build(BuildContext context) => AppMaterialRouter(router: _router);

  @override
  void dispose() {
    _router.dispose();
    _refreshListenable.dispose();
    super.dispose();
  }
}
