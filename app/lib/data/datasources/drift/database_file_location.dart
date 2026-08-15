import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Single source of truth for where the local database file lives — used
/// both to open it (`AppDatabase`) and to locate it for iOS backup
/// exclusion / `resetData()` (`AppBootstrap`). Keeping this in one place
/// means the two can never silently disagree about the path.
const String databaseName = 'roundtablezoo';

Future<File> resolveDatabaseFile() async =>
    File(p.join((await getApplicationDocumentsDirectory()).path, '$databaseName.sqlite'));
