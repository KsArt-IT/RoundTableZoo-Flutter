import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:roundtablezoo/app/app_material_router.dart';
import 'package:roundtablezoo/app/router/app_router.dart';

/// Application entry widget. Global `BlocProvider`s (settings, current day)
/// and `AppLifecycleState` handling join here in later phases (US4, US5).
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final GoRouter _router = buildAppRouter();

  @override
  Widget build(BuildContext context) => AppMaterialRouter(router: _router);
}
