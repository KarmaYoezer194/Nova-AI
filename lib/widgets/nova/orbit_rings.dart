import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/nova_colors.dart';

/// The splash decoration: an outer solid ring and an inner dashed ring,
/// with a small orange and a small teal "planet" on them. Decoration only.
///
/// Every value is passed in, so one painter draws any moment of the
/// animation (and the final, still frame when motion is reduced).
class OrbitRingsPainter extends CustomPainter {
  OrbitRingsPainter({
    required this.colors,
    required this.outerProgress,
    required this.innerOpacity,
    required this.innerTurn,
    required this.dotsOpacity,
    required this.orangeTurn,
    required this.tealTurn,
    super.repaint,
  });

  final NovaColors colors;

  /// How much of the outer ring is drawn, 0–1, clockwise from the top.
  final double outerProgress;

  /// The dashed ring's opacity (0–1) and slow rotation (in turns).
  final double innerOpacity;
  final double innerTurn;

  /// The two dots' opacity, and where they are on their rings (in turns).
  final double dotsOpacity;
  final double orangeTurn;
  final double tealTurn;

  static const double _outerStroke = 1.5;
  static const double _innerStroke = 1.2;
  static const int _dashes = 44;

  /// The rings as a share of the box: outer almost to the edge, inner at
  /// about 70%.
  static const double _outerShare = 0.48;
  static const double _innerShare = 0.345;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerR = size.shortestSide * _outerShare;
    final innerR = size.shortestSide * _innerShare;
    const top = -math.pi / 2;

    if (outerProgress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerR),
        top,
        2 * math.pi * outerProgress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = colors.card
          ..style = PaintingStyle.stroke
          ..strokeWidth = _outerStroke
          ..strokeCap = StrokeCap.round,
      );
    }

    if (innerOpacity > 0) {
      final paint = Paint()
        ..color = colors.cardRaised.withValues(alpha: innerOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _innerStroke;
      const step = 2 * math.pi / _dashes;
      final rect = Rect.fromCircle(center: center, radius: innerR);
      final start = top + innerTurn * 2 * math.pi;
      for (var i = 0; i < _dashes; i++) {
        canvas.drawArc(rect, start + i * step, step * 0.55, false, paint);
      }
    }

    if (dotsOpacity > 0) {
      Offset on(double radius, double turn) =>
          center +
          Offset(
                math.cos(top + turn * 2 * math.pi),
                math.sin(top + turn * 2 * math.pi),
              ) *
              radius;
      // Orange on the outer ring (top right), teal on the inner ring
      // (bottom left) when they first appear.
      canvas.drawCircle(
        on(outerR, 0.13 + orangeTurn),
        5,
        Paint()..color = colors.projectOrange.withValues(alpha: dotsOpacity),
      );
      canvas.drawCircle(
        on(innerR, 0.62 + tealTurn),
        4,
        Paint()..color = colors.projectTeal.withValues(alpha: dotsOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(OrbitRingsPainter old) =>
      old.outerProgress != outerProgress ||
      old.innerOpacity != innerOpacity ||
      old.innerTurn != innerTurn ||
      old.dotsOpacity != dotsOpacity ||
      old.orangeTurn != orangeTurn ||
      old.tealTurn != tealTurn ||
      old.colors != colors;
}
