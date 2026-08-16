import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';
import 'package:roundtablezoo/presentation/storage_recovery/startup_error_page.dart';
import 'package:roundtablezoo/presentation/storage_recovery/storage_recovery_page.dart';

// SC-010 explicitly names these two pre-shell screens alongside the shell's
// own nav destinations (already covered by shell_accessibility_test.dart).

void main() {
  testWidgets('StorageRecoveryPage meets Android tap-target and label guidelines', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => StorageRecoveryCubit(
            // idle(cause) renders all three actions (retry/reset/continue
            // without saving) at once — never actually invoked here.
            createDatabase: () => throw UnimplementedError('not exercised by this test'),
            initialState: const StorageRecoveryState.idle(
              cause: DatabaseFailure(null, code: DatabaseFailure.storageUnavailable),
            ),
          ),
          child: const StorageRecoveryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });

  testWidgets('StartupErrorPage meets Android tap-target and label guidelines', (tester) async {
    final handle = tester.ensureSemantics();

    // Its own top-level MaterialApp (FR-018a) — no wrapping needed.
    await tester.pumpWidget(StartupErrorPage(onRetry: () {}));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });
}
