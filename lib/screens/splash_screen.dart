import 'dart:async';

import 'package:flutter/material.dart';

import '../app/constants.dart';
import '../app/nova_colors.dart';
import '../app/nova_tokens.dart';
import '../app/nova_typography.dart';
import '../widgets/nova/nova_logo.dart';
import '../widgets/nova/orbit_rings.dart';
import '../widgets/typing_indicator.dart';

/// The Flutter splash: shown while Firebase starts and the sign-in state is
/// checked, then hands over to the next screen.
///
/// Timing rules:
/// - It stays only as long as [load] takes. There is no fixed delay.
/// - First launch on a device ([playIntro]): the 1.1 s intro plays to the
///   end, even if loading finishes sooner.
/// - Later launches: the final frame at once (only the logo settles from
///   the native splash's size), and it leaves as soon as loading is done.
/// - Loading longer than 1.1 s: three lime dots show that it's still busy.
/// - Reduce motion: the final frame at once, nothing moves, and a plain
///   200 ms cross-fade to the next screen (no flying logo).
///
/// The first frame shows only the logo, at the native splash's size and
/// place, so the hand-over from the system splash can't be seen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.load,
    this.playIntro = true,
    this.onIntroPlayed,
    this.onFirstFrame,
  });

  /// Starts the app and returns the screen to show next.
  final Future<Widget> Function() load;

  final bool playIntro;

  /// Called once the intro has played to the end (to skip it next time).
  final VoidCallback? onIntroPlayed;

  /// Called after the first frame is drawn (removes the native splash).
  final VoidCallback? onFirstFrame;

  /// The whole intro. Each step below is a slice of it.
  static const Duration introLength = Duration(milliseconds: 1100);

  /// Loading dots appear only if loading is still going after this.
  static const Duration dotsAfter = introLength;

  static const Duration exitFade = Duration(milliseconds: 300);
  static const Duration exitFadeReduced = Duration(milliseconds: 200);

  /// The looping motion: 60 s holds whole turns of everything (inner ring
  /// 3 turns = one per 20 s; orange 1 turn; teal 2 turns), so it repeats
  /// without a jump.
  static const Duration loopLength = Duration(seconds: 60);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// A slice of the intro, in milliseconds, with its curve.
Interval _ms(int from, int to, [Curve curve = Curves.linear]) {
  const total = 1100;
  return Interval(from / total, to / total, curve: curve);
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: SplashScreen.introLength,
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: SplashScreen.loopLength,
  );

  /// Later launches: the logo grows from the native splash's size.
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  Widget? _next;
  bool _started = false;
  bool _leaving = false;
  bool _dotsDue = false;
  Timer? _dotsTimer;
  late bool _reduceMotion;

  static const double _startScale =
      NovaSize.nativeSplashLogo / NovaSize.splashLogo;

  // The intro's steps (see the design's timeline).
  static final _logoScale = _ms(0, 450, Curves.easeOutBack);
  static final _moon = _ms(100, 700, Curves.easeInOutCubic);
  static final _outerRing = _ms(150, 850, Curves.easeOutCubic);
  static final _innerRing = _ms(300, 900);
  static final _dots = _ms(400, 900, Curves.easeOut);
  static final _tagline = _ms(800, 1100, Curves.easeOut);
  static Interval _letter(int i) =>
      _ms(500 + 40 * i, 780 + 40 * i, Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onFirstFrame?.call();
    });
    _dotsTimer = Timer(SplashScreen.dotsAfter, () {
      if (mounted) setState(() => _dotsDue = true);
    });
    widget.load().then((next) {
      if (!mounted) return;
      _next = next;
      _maybeLeave();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;

    if (_reduceMotion) {
      // The final frame, still.
      _intro.value = 1;
      _settle.value = 1;
      return;
    }
    _loop.repeat();
    if (widget.playIntro) {
      _settle.value = 1;
      _intro.forward().whenComplete(() {
        if (!mounted) return;
        widget.onIntroPlayed?.call();
        _maybeLeave();
      });
    } else {
      _intro.value = 1;
      _settle.forward();
    }
  }

  bool get _introDone => _intro.isCompleted;

  void _maybeLeave() {
    final next = _next;
    if (next == null || !_introDone || _leaving) return;
    _leaving = true;
    // The looping motion stops as the next screen takes over.
    _loop.stop();
    _dotsTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => next,
        transitionDuration: _reduceMotion
            ? SplashScreen.exitFadeReduced
            : SplashScreen.exitFade,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    _intro.dispose();
    _loop.dispose();
    _settle.dispose();
    super.dispose();
  }

  double _at(Interval step) => step.transform(_intro.value);

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    final text = NovaText.of(context);
    final theme = Theme.of(context);
    final loading = _next == null;

    return Scaffold(
      backgroundColor: c.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The logo sits exactly in the middle of the screen, like the
          // native splash; the words go under the rings.
          final textTop =
              constraints.maxHeight / 2 +
              NovaSize.splashOrbits / 2 +
              NovaSpace.md;
          return Stack(
            children: [
              Center(
                child: SizedBox.square(
                  dimension: NovaSize.splashOrbits,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Repaints on its own layer, so the moving rings
                      // never redraw the rest of the screen.
                      Positioned.fill(
                        child: ExcludeSemantics(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _RingsDriver(
                                colors: c,
                                intro: _intro,
                                loop: _loop,
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: Listenable.merge([_intro, _settle]),
                        builder: (context, _) {
                          final grow = widget.playIntro
                              ? _at(_logoScale)
                              : Curves.easeOutCubic.transform(_settle.value);
                          final scale = _startScale + (1 - _startScale) * grow;
                          return Transform.scale(
                            scale: scale,
                            child: HeroMode(
                              // Reduce motion: no flying logo.
                              enabled: !_reduceMotion,
                              child: NovaLogo(
                                size: NovaSize.splashLogo,
                                hero: true,
                                semanticLabel: AppConstants.appName,
                                moonTurn: -1 + _at(_moon),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: textTop,
                left: NovaSpace.lg,
                right: NovaSpace.lg,
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) => Column(
                    children: [
                      Semantics(
                        label: AppConstants.appName,
                        excludeSemantics: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final (i, letter)
                                in AppConstants.appName
                                    .toLowerCase()
                                    .split('')
                                    .indexed)
                              _risingLetter(letter, _at(_letter(i)), text),
                          ],
                        ),
                      ),
                      const SizedBox(height: NovaSpace.xs),
                      Opacity(
                        opacity: _at(_tagline),
                        child: Text(
                          'Think out loud.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: NovaSpace.xxl + MediaQuery.paddingOf(context).bottom,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: loading && _dotsDue ? 1 : 0,
                    duration: _reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    child: loading && _dotsDue
                        ? (_reduceMotion
                              ? const _StillDots()
                              : const TypingIndicator(label: 'Loading'))
                        : const SizedBox(height: NovaSpace.xl),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// One letter of "nova": rises 8 px and fades in as [t] goes 0 → 1.
  Widget _risingLetter(String letter, double t, NovaText text) {
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, NovaSpace.sm * (1 - t)),
        child: Text(letter, style: text.splashWordmark),
      ),
    );
  }
}

/// Feeds the animation values into [OrbitRingsPainter]. It repaints from
/// the controllers directly (no widget rebuilds).
class _RingsDriver extends CustomPainter {
  _RingsDriver({required this.colors, required this.intro, required this.loop})
    : super(repaint: Listenable.merge([intro, loop]));

  final NovaColors colors;
  final Animation<double> intro;
  final Animation<double> loop;

  @override
  void paint(Canvas canvas, Size size) {
    double at(Interval step) => step.transform(intro.value);
    OrbitRingsPainter(
      colors: colors,
      outerProgress: at(_SplashScreenState._outerRing),
      innerOpacity: at(_SplashScreenState._innerRing),
      innerTurn: loop.value * 3,
      dotsOpacity: at(_SplashScreenState._dots),
      orangeTurn: loop.value,
      tealTurn: loop.value * 2,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_RingsDriver old) =>
      old.colors != colors || old.intro != intro || old.loop != loop;
}

/// Reduce motion: the loading dots, not moving.
class _StillDots extends StatelessWidget {
  const _StillDots();

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    return Semantics(
      label: 'Loading',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: NovaSpace.sm,
              height: NovaSpace.sm,
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
