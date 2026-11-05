import 'package:flutter/material.dart';

import '../app/constants.dart';
import '../app/nova_colors.dart';
import '../app/nova_icons.dart';
import '../app/nova_tokens.dart';
import '../app/nova_typography.dart';
import '../widgets/nova/nova_button.dart';
import '../widgets/nova/nova_icon_button.dart';
import '../widgets/nova/nova_logo.dart';
import 'privacy_screen.dart';

/// How the user left the welcome tour.
enum OnboardingExit {
  /// Skip (on any step).
  skip,

  /// "Create an account" on the last step.
  createAccount,

  /// "I already have an account" on the last step.
  signIn,

  /// "Done" on the last step of a replay from Settings.
  done,
}

/// One step of the tour. The heading's last words ([accent]) are lime.
class OnboardingStep {
  const OnboardingStep({
    required this.image,
    required this.lead,
    required this.accent,
    required this.body,
  });

  final String image;
  final String lead;
  final String accent;
  final String body;

  String get heading => '$lead$accent';
}

const List<OnboardingStep> onboardingSteps = [
  OnboardingStep(
    image: 'assets/onboarding/meet_nova.jpg',
    lead: 'Meet ${AppConstants.assistantName}, your ',
    accent: 'study partner',
    body: 'Ask anything and watch clear answers write themselves as you read.',
  ),
  OnboardingStep(
    image: 'assets/onboarding/projects_memory.jpg',
    lead: 'Stay organised, ',
    accent: 'your way',
    body:
        'Group chats into projects, and choose what '
        '${AppConstants.assistantName} remembers. You can see or delete it '
        'any time.',
  ),
  OnboardingStep(
    image: 'assets/onboarding/files_links.jpg',
    lead: 'Bring your ',
    accent: 'notes along',
    body:
        'Attach a photo or PDF, or paste a link, and '
        '${AppConstants.assistantName} reads it with you.',
  ),
];

/// The wide layout's image, on every step.
const String onboardingDesktopImage = 'assets/onboarding/files_links.jpg';

/// The welcome tour: three steps, then sign-up or sign-in.
///
/// Phones: a big image on top of each step, swipe or Next to move on.
/// Wide screens (900 px and up): the books image on the left, the steps on
/// the right. Skip is on every step. With [replay] (from Settings), the
/// last step has one "Done" button instead of the account buttons.
///
/// The images are decoration only: screen readers skip them, and the
/// heading and text carry the meaning.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinish,
    this.replay = false,
  });

  final ValueChanged<OnboardingExit> onFinish;
  final bool replay;

  static const double wideLayout = 900;

  /// How long a step change takes (when motion is allowed).
  static const Duration stepMotion = Duration(milliseconds: 250);
  static const Duration pageSlide = Duration(milliseconds: 320);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _index = 0;

  /// Only while the phone layout is showing (it owns the swiping).
  PageController? _pages;
  bool _precached = false;

  static int get _last => onboardingSteps.length - 1;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  Duration get _motion =>
      _reduceMotion ? Duration.zero : OnboardingScreen.stepMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode all three images now, so every step appears instantly.
    if (_precached) return;
    _precached = true;
    for (final step in onboardingSteps) {
      precacheImage(AssetImage(step.image), context, onError: (_, _) {});
    }
  }

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    final target = index.clamp(0, _last);
    final pages = _pages;
    if (pages != null && pages.hasClients) {
      if (_reduceMotion) {
        pages.jumpToPage(target);
      } else {
        pages.animateToPage(
          target,
          duration: OnboardingScreen.pageSlide,
          curve: Curves.easeInOutCubic,
        );
      }
    }
    // The phone layout also updates from onPageChanged; this covers wide
    // screens and makes the step dots move at once.
    setState(() => _index = target);
  }

  void _finish(OnboardingExit exit) => widget.onFinish(exit);

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= OnboardingScreen.wideLayout) {
            _dropPageController();
            return _wide(context);
          }
          return _phone(context, constraints.maxHeight);
        },
      ),
    );
  }

  /// Wide screens don't swipe. A new phone layout starts at the current
  /// step with a fresh controller.
  void _dropPageController() {
    final old = _pages;
    if (old == null) return;
    _pages = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  // ---------- Phones ----------

  /// The image's share of the screen height: a little less on the last
  /// step, which has more buttons.
  static double _imageShare(int step) => step == _last ? 0.46 : 0.56;

  Widget _phone(BuildContext context, double height) {
    final pages = _pages ??= PageController(initialPage: _index);
    final padding = MediaQuery.paddingOf(context);

    // Between two steps (while swiping) the dots follow the image's edge.
    double imageHeight() {
      final page = pages.hasClients && pages.position.haveDimensions
          ? pages.page ?? _index.toDouble()
          : _index.toDouble();
      final from = page.floor().clamp(0, _last);
      final to = page.ceil().clamp(0, _last);
      final t = page - page.floor();
      return (height *
              (_imageShare(from) + (_imageShare(to) - _imageShare(from)) * t))
          .roundToDouble();
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              PageView.builder(
                controller: pages,
                itemCount: onboardingSteps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _PhoneStep(
                  step: onboardingSteps[i],
                  // Whole pixels, so no thin line of image peeks out
                  // under its fade.
                  imageHeight: (height * _imageShare(i)).roundToDouble(),
                  active: i == _index,
                  motion: _motion,
                ),
              ),
              // Top: the logo on step 1, Back on the others; Skip at the
              // right on every step.
              Positioned(
                top: padding.top + NovaSpace.md,
                left: NovaSpace.lg,
                right: NovaSpace.lg,
                child: Row(
                  children: [
                    if (_index == 0)
                      const _Wordmark()
                    else
                      _OverImage(
                        child: NovaIconButton(
                          tooltip: 'Back',
                          icon: NovaIcons.back,
                          shape: NovaIconButtonShape.square,
                          onPressed: () => _goTo(_index - 1),
                        ),
                      ),
                    const Spacer(),
                    _OverImage(
                      child: _SkipPill(
                        onPressed: () => _finish(OnboardingExit.skip),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: NovaSpace.lg + NovaSpace.xs,
                child: AnimatedBuilder(
                  animation: pages,
                  builder: (context, child) => Padding(
                    padding: EdgeInsets.only(top: imageHeight() + NovaSpace.md),
                    child: child,
                  ),
                  child: StepDots(
                    index: _index,
                    count: onboardingSteps.length,
                    motion: _motion,
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              NovaSpace.lg + NovaSpace.xs,
              NovaSpace.sm,
              NovaSpace.lg + NovaSpace.xs,
              NovaSpace.lg,
            ),
            child: _index < _last
                ? Align(alignment: Alignment.centerRight, child: _nextButton())
                : _finalActions(context, centred: true),
          ),
        ),
      ],
    );
  }

  Widget _nextButton() => NovaButton(
    label: 'Next',
    icon: NovaIcons.next,
    iconAfter: true,
    pill: true,
    large: true,
    onPressed: () => _goTo(_index + 1),
  );

  /// The last step: the account buttons (or Done when replaying), and the
  /// disclaimer with the Privacy notice.
  Widget _finalActions(BuildContext context, {required bool centred}) {
    final buttons = widget.replay
        ? [
            NovaButton(
              label: 'Done',
              pill: true,
              large: true,
              expand: true,
              onPressed: () => _finish(OnboardingExit.done),
            ),
          ]
        : [
            NovaButton(
              label: 'Create an account',
              pill: true,
              large: true,
              expand: true,
              onPressed: () => _finish(OnboardingExit.createAccount),
            ),
            const SizedBox(height: NovaSpace.md),
            NovaButton.secondary(
              label: 'I already have an account',
              pill: true,
              large: true,
              expand: true,
              onPressed: () => _finish(OnboardingExit.signIn),
            ),
          ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...buttons,
        const SizedBox(height: NovaSpace.sm),
        _Footer(centred: centred),
      ],
    );
  }

  // ---------- Wide screens ----------

  Widget _wide(BuildContext context) {
    final step = onboardingSteps[_index];
    final textTheme = NovaText.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(NovaSpace.appPadding),
        child: Row(
          children: [
            Expanded(
              flex: 11,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(NovaRadius.panel),
                child: const _StepImage(
                  image: onboardingDesktopImage,
                  active: true,
                  motion: Duration.zero,
                  fadeBottom: false,
                ),
              ),
            ),
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NovaSpace.xxl + NovaSpace.lg,
                  NovaSpace.xl,
                  NovaSpace.xl,
                  NovaSpace.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _Wordmark(),
                        const Spacer(),
                        _SkipPill(
                          onPressed: () => _finish(OnboardingExit.skip),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StepDots(
                                  index: _index,
                                  count: onboardingSteps.length,
                                  motion: _motion,
                                ),
                                const SizedBox(height: NovaSpace.xl),
                                // The text changes; the image stays.
                                AnimatedSwitcher(
                                  duration: _motion,
                                  transitionBuilder: _fadeUp,
                                  layoutBuilder: (current, previous) => Stack(
                                    alignment: Alignment.topLeft,
                                    children: [...previous, ?current],
                                  ),
                                  child: _StepText(
                                    key: ValueKey(_index),
                                    step: step,
                                    headingStyle: textTheme.onboardingDisplay,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_index < _last)
                      Row(
                        children: [
                          if (_index > 0)
                            TextButton.icon(
                              onPressed: () => _goTo(_index - 1),
                              icon: const Icon(
                                NovaIcons.back,
                                size: NovaSize.icon,
                              ),
                              label: const Text('Back'),
                            ),
                          const Spacer(),
                          _nextButton(),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _goTo(_index - 1),
                            icon: const Icon(
                              NovaIcons.back,
                              size: NovaSize.icon,
                            ),
                            label: const Text('Back'),
                          ),
                          const Spacer(),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: _finalActions(context, centred: true),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _fadeUp(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// One step on a phone: the image (fading into the page at its bottom)
/// and, under the step dots, the heading and text.
class _PhoneStep extends StatelessWidget {
  const _PhoneStep({
    required this.step,
    required this.imageHeight,
    required this.active,
    required this.motion,
  });

  final OnboardingStep step;
  final double imageHeight;
  final bool active;
  final Duration motion;

  /// Room for the step dots (drawn above the pages) under the image.
  static const double _dotsSpace =
      NovaSpace.md + NovaSize.stepDot + NovaSpace.lg + NovaSpace.xs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: imageHeight,
          child: _StepImage(
            image: step.image,
            active: active,
            motion: motion,
            fadeBottom: true,
          ),
        ),
        Expanded(
          // Scrolls at very large text sizes instead of overflowing.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              NovaSpace.lg + NovaSpace.xs,
              _dotsSpace,
              NovaSpace.lg + NovaSpace.xs,
              NovaSpace.md,
            ),
            child: AnimatedOpacity(
              opacity: active || motion == Duration.zero ? 1 : 0,
              duration: motion,
              curve: Curves.easeOut,
              child: AnimatedSlide(
                offset: active || motion == Duration.zero
                    ? Offset.zero
                    : const Offset(0, 0.06),
                duration: motion,
                curve: Curves.easeOut,
                child: _StepText(
                  step: step,
                  headingStyle: theme.textTheme.headlineLarge,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The heading (last words lime) and the text of a step.
class _StepText extends StatelessWidget {
  const _StepText({super.key, required this.step, this.headingStyle});

  final OnboardingStep step;
  final TextStyle? headingStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = NovaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: step.lead),
                TextSpan(
                  text: step.accent,
                  style: TextStyle(color: c.accent),
                ),
              ],
            ),
            style: headingStyle,
          ),
        ),
        const SizedBox(height: NovaSpace.md),
        Text(
          step.body,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: c.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

/// A step's picture: fills its box (cover), zooms gently from 1.04 to 1
/// when the step appears, and (on phones) fades into the page at the
/// bottom. A soft shade at the top keeps the logo and buttons readable.
/// Decoration only: screen readers skip it.
class _StepImage extends StatelessWidget {
  const _StepImage({
    required this.image,
    required this.active,
    required this.motion,
    required this.fadeBottom,
  });

  final String image;
  final bool active;
  final Duration motion;
  final bool fadeBottom;

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    return ExcludeSemantics(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: active || motion == Duration.zero ? 1 : 1.04,
              duration: motion,
              curve: Curves.easeOut,
              child: Image.asset(
                image,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                gaplessPlayback: true,
                // If the file is missing, a calm panel instead of an error.
                errorBuilder: (context, _, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [c.panel, c.background],
                    ),
                  ),
                ),
              ),
            ),
            if (fadeBottom) ...[
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: NovaSpace.xxl * 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        c.background.withValues(alpha: 0.55),
                        c.background.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: NovaSpace.xxl * 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [c.background.withValues(alpha: 0), c.background],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The step dots: the current step is a 24 × 8 lime pill, the others 8 × 8
/// dots. Screen readers hear "Step 1 of 3" (announced when it changes).
class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.index,
    required this.count,
    required this.motion,
  });

  final int index;
  final int count;
  final Duration motion;

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    return Semantics(
      label: 'Step ${index + 1} of $count',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: motion,
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: NovaSpace.xs + 2),
                width: i == index ? NovaSize.stepDotActive : NovaSize.stepDot,
                height: NovaSize.stepDot,
                decoration: BoxDecoration(
                  color: i == index ? c.accent : c.fieldOutline,
                  borderRadius: BorderRadius.circular(NovaRadius.pill),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The small logo and "nova". The logo is where the splash logo lands.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NovaLogo(hero: true),
        const SizedBox(width: NovaSpace.sm + 2),
        Semantics(
          label: AppConstants.appName,
          excludeSemantics: true,
          child: Text(
            AppConstants.appName.toLowerCase(),
            style: NovaText.of(context).logo,
          ),
        ),
      ],
    );
  }
}

/// A see-through panel behind a control on top of the image, so it stays
/// readable on any picture.
class _OverImage extends StatelessWidget {
  const _OverImage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.panel.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(NovaRadius.row),
      ),
      child: child,
    );
  }
}

/// "Skip ›" as a small outlined pill, top right on every step.
class _SkipPill extends StatelessWidget {
  const _SkipPill({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: c.textSecondary,
        side: BorderSide(color: c.outline),
        shape: const StadiumBorder(),
        minimumSize: const Size(
          NovaSize.minTouchTarget,
          NovaSize.minTouchTarget,
        ),
        padding: const EdgeInsets.symmetric(horizontal: NovaSpace.lg),
        textStyle: NovaText.of(context).small,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Skip'),
          SizedBox(width: NovaSpace.xs),
          Icon(NovaIcons.skip, size: NovaSize.iconSmall),
        ],
      ),
    );
  }
}

/// The disclaimer and the Privacy notice link, under the last buttons.
class _Footer extends StatelessWidget {
  const _Footer({required this.centred});
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final text = NovaText.of(context);
    return Wrap(
      alignment: centred ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          AppConstants.disclaimer,
          style: text.caption,
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: NovaSpace.xs),
            minimumSize: const Size(
              NovaSize.minTouchTarget,
              NovaSize.minTouchTarget,
            ),
            textStyle: text.caption.copyWith(
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Privacy notice'),
        ),
      ],
    );
  }
}
