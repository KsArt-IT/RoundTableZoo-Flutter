import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/onboarding/cubit/onboarding_cubit.dart';
import 'package:roundtablezoo/presentation/onboarding/cubit/onboarding_state.dart';
import 'package:roundtablezoo/presentation/onboarding/onboarding_page.dart';

import '../support/mocks.dart';

Widget _wrapped() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider(
    create: (_) => OnboardingCubit(
      settingsRepositoryLocator: () => MockSettingsRepository(),
      initialState: const OnboardingState.required(),
    ),
    child: const OnboardingPage(),
  ),
);

void main() {
  testWidgets('OnboardingPage meets Android tap-target and label guidelines (FR-010)', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(_wrapped());
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });

  testWidgets('title and all three points are visible to a screen reader (FR-010)', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(_wrapped());
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(
      Localizations.localeOf(tester.element(find.byType(OnboardingPage))),
    );
    expect(find.text(l10n.onboardingTitle), findsOneWidget);
    expect(find.text(l10n.onboardingHowTo), findsOneWidget);
    expect(find.text(l10n.onboardingDisclaimer), findsOneWidget);
    expect(find.text(l10n.onboardingAiDisclosure), findsOneWidget);

    handle.dispose();
  });

  testWidgets('accessibility focus lands on the title when the screen opens (FR-010a)', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(_wrapped());
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(
      Localizations.localeOf(tester.element(find.byType(OnboardingPage))),
    );
    final titleSemantics = tester.getSemantics(find.text(l10n.onboardingTitle));
    expect(titleSemantics.flagsCollection.isFocused, Tristate.isTrue);

    handle.dispose();
  });

  testWidgets('no overflow at 2x text scale (FR-010b)', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _wrapped(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at a 320dp-wide screen (FR-010b)', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapped());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
