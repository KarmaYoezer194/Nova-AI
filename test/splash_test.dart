// Splash screen and start routing (splash and onboarding, Round A).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/nova_tokens.dart';
import 'package:nova_chat/app/theme.dart';
import 'package:nova_chat/screens/auth_gate.dart';
import 'package:nova_chat/screens/splash_screen.dart';
import 'package:nova_chat/widgets/nova/nova_logo.dart';
import 'package:nova_chat/widgets/typing_indicator.dart';

/// Stands in for the screen after the splash, with the Hero target.
class _Next extends StatelessWidget {
  const _Next();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Column(children: [NovaLogo(hero: true), Text('Next screen')]),
  );
}

/// The splash logo's size as drawn on screen.
double logoSize(WidgetTester tester) => tester
    .getRect(
      find.descendant(
        of: find.byType(NovaLogo),
        matching: find.byType(CustomPaint),
      ),
    )
    .width;

void main() {
  group('start route', () {
    test('signed in → chats, whatever the tour flag', () {
      for (final seen in [true, false]) {
        expect(
          startRouteFor(signedIn: true, onboardingSeen: seen),
          StartRoute.chat,
        );
      }
    });

    test('signed out → tour on a first visit, then sign-in', () {
      expect(
        startRouteFor(signedIn: false, onboardingSeen: false),
        StartRoute.onboarding,
      );
      expect(
        startRouteFor(signedIn: false, onboardingSeen: true),
        StartRoute.signIn,
      );
    });
  });

  group('splash', () {
    Future<void> pumpSplash(
      WidgetTester tester, {
      required Future<Widget> Function() load,
      bool playIntro = true,
      bool reduceMotion = false,
      VoidCallback? onIntroPlayed,
      VoidCallback? onFirstFrame,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: SplashScreen(
            load: load,
            playIntro: playIntro,
            onIntroPlayed: onIntroPlayed,
            onFirstFrame: onFirstFrame,
          ),
        ),
      );
    }

    testWidgets('first launch: the intro plays to the end even if loading '
        'is done sooner', (tester) async {
      var played = 0, firstFrame = 0;
      await pumpSplash(
        tester,
        load: () async => const _Next(),
        onIntroPlayed: () => played++,
        onFirstFrame: () => firstFrame++,
      );
      expect(firstFrame, 1); // The native splash is removed.

      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Next screen'), findsNothing);
      expect(played, 0);

      await tester.pump(const Duration(milliseconds: 600)); // Intro done.
      expect(played, 1);
      await tester.pump(const Duration(milliseconds: 400)); // Fade + Hero.
      expect(find.text('Next screen'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('first frame: only the logo, at the native splash size', (
      tester,
    ) async {
      final load = Completer<Widget>();
      await pumpSplash(tester, load: () => load.future);
      // The words haven't faded in yet.
      final nova = tester.widget<Opacity>(
        find.ancestor(of: find.text('n'), matching: find.byType(Opacity)).first,
      );
      expect(nova.opacity, 0);
      // Drawn at 82 px: the same size as the native splash's logo.
      expect(logoSize(tester), closeTo(NovaSize.nativeSplashLogo, 0.5));

      load.complete(const _Next());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('later launches: no intro, leaves as soon as loading is done', (
      tester,
    ) async {
      final load = Completer<Widget>();
      var played = 0;
      await pumpSplash(
        tester,
        load: () => load.future,
        playIntro: false,
        onIntroPlayed: () => played++,
      );
      // The final frame at once: the words are already there.
      expect(find.text('Think out loud.'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50));
      load.complete(const _Next());
      await tester.pump(); // Loading done → leaving.
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Next screen'), findsOneWidget);
      expect(played, 0);
    });

    testWidgets('slow loading: the three dots appear after the intro, '
        'labelled "Loading"', (tester) async {
      final semantics = tester.ensureSemantics();
      final load = Completer<Widget>();
      await pumpSplash(tester, load: () => load.future);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(TypingIndicator), findsNothing);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TypingIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 350)); // Faded in.
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      semantics.dispose();

      load.complete(const _Next());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Next screen'), findsOneWidget);
    });

    testWidgets('reduce motion: final frame at once, 200 ms fade, '
        'no flying logo', (tester) async {
      final load = Completer<Widget>();
      await pumpSplash(tester, load: () => load.future, reduceMotion: true);

      // Everything already in its final place.
      expect(logoSize(tester), closeTo(NovaSize.splashLogo, 0.5));
      expect(
        tester
            .widget<HeroMode>(
              find.ancestor(
                of: find.byType(NovaLogo),
                matching: find.byType(HeroMode),
              ),
            )
            .enabled,
        isFalse,
      );

      load.complete(const _Next());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 210));
      expect(find.text('Next screen'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('the looping motion stops once the splash has left', (
      tester,
    ) async {
      await pumpSplash(tester, load: () async => const _Next());
      await tester.pump(const Duration(milliseconds: 1200));
      // Nothing keeps animating: settling would time out otherwise.
      await tester.pumpAndSettle();
      expect(find.text('Next screen'), findsOneWidget);
    });
  });
}
