import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Application logger. Use instead of print/debugPrint everywhere.
final Logger logger = Logger(
  level: kReleaseMode ? Level.off : Level.debug,
  printer: PrettyPrinter(methodCount: 1, colors: false, printEmojis: false),
);
