import 'package:flutter/material.dart';
import 'package:roundtablezoo/app/app_root.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/time_zone/time_zones.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TimeZones.initialize();
  configureDependencies();
  runApp(const AppRoot());
}
