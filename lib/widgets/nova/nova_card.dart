import 'package:flutter/material.dart';

import '../../app/nova_colors.dart';
import '../../app/nova_tokens.dart';

/// A rounded surface: Nova's answers, suggestion and project cards.
///
/// Tappable when [onTap] is set (then it shows hover and press states).
class NovaCard extends StatelessWidget {
  const NovaCard({
    super.key,
    required this.child,
    this.onTap,
    this.raised = false,
    this.radius = NovaRadius.card,
    this.padding = const EdgeInsets.symmetric(
      vertical: NovaSpace.cardPaddingV,
      horizontal: NovaSpace.cardPaddingH,
    ),
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Uses `cardRaised` (tiles inside cards) instead of `card`.
  final bool raised;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    final shape = BorderRadius.circular(radius);
    final content = Padding(padding: padding, child: child);
    return Material(
      color: raised ? c.cardRaised : c.card,
      borderRadius: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: shape, child: content),
    );
  }
}
