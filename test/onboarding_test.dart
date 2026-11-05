// Welcome tour (splash and onboarding, Round B).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/theme.dart';
import 'package:nova_chat/screens/auth_gate.dart';
import 'package:nova_chat/screens/onboarding_screen.dart';
import 'package:nova_chat/screens/settings_screen.dart';
import 'package:nova_chat/screens/sign_in_screen.dart';

import 'fakes.dart';

void main() {
  Future<void> pumpTour(
    WidgetTester tester, {
    required ValueChanged<OnboardingExit> onFinish,
    Size size = const Size(390, 844),
    bool replay = false,
    bool reduceMotion = false,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: OnboardingScreen(onFinish: onFinish, replay: replay),
      ),
    );
    await tester.pump();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }

  group('phone', () {
    testWidgets('three steps with Next, Back and the step dots', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpTour(tester, onFinish: (_) {});

      expect(find.textContaining('study partner'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing); // The logo instead.

      await next(tester);
      expect(find.textContaining('your way'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      await next(tester);
      expect(find.textContaining('notes along'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
      expect(find.text('Privacy notice'), findsOneWidget);
      expect(find.text('Next'), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('swiping moves between steps', (tester) async {
      await pumpTour(tester, onFinish: (_) {});
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Next'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
    });

    testWidgets('Skip on every step', (tester) async {
      final exits = <OnboardingExit>[];
      await pumpTour(tester, onFinish: exits.add);
      for (var step = 0; step < 3; step++) {
        await tester.tap(find.text('Skip'));
        await tester.pump();
        if (step < 2) await next(tester);
      }
      expect(exits, List.filled(3, OnboardingExit.skip));
    });

    testWidgets('the last step\'s two buttons', (tester) async {
      final exits = <OnboardingExit>[];
      await pumpTour(tester, onFinish: exits.add);
      await next(tester);
      await next(tester);
      await tester.tap(find.text('Create an account'));
      await tester.tap(find.text('I already have an account'));
      expect(exits, [OnboardingExit.createAccount, OnboardingExit.signIn]);
    });

    testWidgets('replay from Settings ends with Done', (tester) async {
      final exits = <OnboardingExit>[];
      await pumpTour(tester, onFinish: exits.add, replay: true);
      await next(tester);
      await next(tester);
      expect(find.text('Create an account'), findsNothing);
      await tester.tap(find.text('Done'));
      expect(exits, [OnboardingExit.done]);
    });

    testWidgets('reduce motion: steps change at once', (tester) async {
      await pumpTour(tester, onFinish: (_) {}, reduceMotion: true);
      await tester.tap(find.text('Next'));
      await tester.pump(); // One frame, no animation.
      expect(find.textContaining('your way'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
    });

    testWidgets('largest text size: nothing overflows', (tester) async {
      await pumpTour(tester, onFinish: (_) {}, textScale: 2);
      await next(tester);
      await next(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Create an account'), findsOneWidget);
    });
  });

  group('wide', () {
    testWidgets('one image on all steps, Skip at the top, Next at the '
        'bottom', (tester) async {
      final exits = <OnboardingExit>[];
      await pumpTour(tester, onFinish: exits.add, size: const Size(1440, 900));

      expect(find.byType(PageView), findsNothing);
      expect(find.textContaining('study partner'), findsOneWidget);
      await next(tester);
      expect(find.textContaining('your way'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      await next(tester);
      expect(find.text('Create an account'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      expect(exits, [OnboardingExit.skip]);
    });
  });

  group('routing', () {
    Future<FakeDevicePrefs> pumpGate(
      WidgetTester tester, {
      required bool onboardingSeen,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prefs = FakeDevicePrefs(onboarding: onboardingSeen);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: AuthGate(
            services: fakeServices(auth: FakeSignedOutAuth()),
            signInChecked: true,
            onboardingSeen: onboardingSeen,
            prefs: prefs,
          ),
        ),
      );
      await tester.pump();
      return prefs;
    }

    testWidgets('first visit: the tour; Skip saves it and opens sign-in', (
      tester,
    ) async {
      final prefs = await pumpGate(tester, onboardingSeen: false);
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(prefs.onboarding, isTrue);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('"Create an account" opens sign-in in registration mode', (
      tester,
    ) async {
      final prefs = await pumpGate(tester, onboardingSeen: false);
      await next(tester);
      await next(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pump();
      expect(prefs.onboarding, isTrue);
      expect(find.text('Create your account'), findsOneWidget);
    });

    testWidgets('"I already have an account" opens sign-in', (tester) async {
      final prefs = await pumpGate(tester, onboardingSeen: false);
      await next(tester);
      await next(tester);
      await tester.tap(find.text('I already have an account'));
      await tester.pump();
      expect(prefs.onboarding, isTrue);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('tour already seen: straight to sign-in', (tester) async {
      await pumpGate(tester, onboardingSeen: true);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  testWidgets('Settings: "Show welcome tour" replays it, Done closes it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = fakeServices();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SettingsScreen(
          services: services,
          uid: 'user-a',
          email: 'a@example.com',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Show welcome tour'));
    await tester.tap(find.text('Show welcome tour'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Show welcome tour'), findsOneWidget);
  });
}
