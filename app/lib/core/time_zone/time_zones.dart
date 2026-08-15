import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:roundtablezoo/core/utils/app_logger.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

abstract class TimeZones {
  static Future<void> initialize() async {
    await _configureLocalTimeZone();
  }

  static Future<void> _configureLocalTimeZone() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.linux) return;

    tz.initializeTimeZones();

    if (defaultTargetPlatform == TargetPlatform.windows) return;

    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName.identifier));
    logger.d('Local timezone: ${timeZoneName.identifier}');
  }
}
