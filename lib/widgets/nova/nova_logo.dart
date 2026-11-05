import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/nova_colors.dart';
import '../../app/nova_tokens.dart';

/// The Hero tag of the logo that flies from the splash to the next screen.
/// Only ONE logo per screen may use it (see [NovaLogo.hero]).
const String novaLogoHeroTag = 'nova-logo';

/// Nova's mark: a lime circle with a dark ring and a small "moon" dot.
///
/// Drawn in code (the same shapes as assets/images/nova_logo.svg), so it
/// shows instantly, with no file to load, and the splash can move the moon.
///
/// Sizes: [NovaSize.logoSidebar] (sidebar), [NovaSize.logoAnswer] (next to
/// answers), [NovaSize.logoHero] (new-chat screen).
class NovaLogo extends StatelessWidget {
  const NovaLogo({
    super.key,
    this.size = NovaSize.logoSidebar,
    this.semanticLabel,
    this.hero = false,
    this.moonTurn = 0,
  });

  final double size;

  /// What a screen reader says. Leave null when the word "Nova" is next to
  /// the logo anyway, so it isn't read twice.
  final String? semanticLabel;

  /// True for the one logo on a screen that the splash logo flies to.
  final bool hero;

  /// How far the moon is from its resting spot, in turns (0 = resting,
  /// -1 = one full orbit before it). Used by the splash animation.
  final double moonTurn;

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    Widget logo = CustomPaint(
      size: Size.square(size),
      painter: NovaLogoPainter(
        lime: c.accent,
        dark: c.background,
        moonTurn: moonTurn,
      ),
    );
    logo = semanticLabel == null
        ? ExcludeSemantics(child: logo)
        : Semantics(label: semanticLabel, image: true, child: logo);
    return hero ? Hero(tag: novaLogoHeroTag, child: logo) : logo;
  }
}

/// Paints the logo in a square, on the 28 × 28 grid of the SVG.
class NovaLogoPainter extends CustomPainter {
  NovaLogoPainter({required this.lime, required this.dark, this.moonTurn = 0});

  final Color lime;
  final Color dark;
  final double moonTurn;

  // The SVG's shapes.
  static const _ringCenter = Offset(13, 15);
  static const _ringRadius = 6.0;
  static const _ringStroke = 2.4;
  static const _moonRest = Offset(20.5, 7.5);
  static const _moonRadius = 2.6;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 28, size.height / 28);
    canvas.drawCircle(const Offset(14, 14), 14, Paint()..color = lime);
    canvas.drawCircle(
      _ringCenter,
      _ringRadius,
      Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringStroke,
    );
    // The moon orbits the ring's centre. The lime disc is clipped so a moon
    // passing its edge never pokes outside the logo.
    canvas.clipPath(
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(14, 14), radius: 14)),
    );
    canvas.drawCircle(
      moonPosition(moonTurn),
      _moonRadius,
      Paint()..color = dark,
    );
    canvas.restore();
  }

  /// Where the moon is (on the 28 grid) after [turn] turns from rest.
  static Offset moonPosition(double turn) {
    final rest = _moonRest - _ringCenter;
    final angle = math.atan2(rest.dy, rest.dx) + turn * 2 * math.pi;
    return _ringCenter +
        Offset(math.cos(angle), math.sin(angle)) * rest.distance;
  }

  @override
  bool shouldRepaint(NovaLogoPainter old) =>
      old.lime != lime || old.dark != dark || old.moonTurn != moonTurn;
}
