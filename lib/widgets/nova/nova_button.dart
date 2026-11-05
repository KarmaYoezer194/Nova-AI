import 'package:flutter/material.dart';

import '../../app/nova_colors.dart';
import '../../app/nova_tokens.dart';

enum NovaButtonKind {
  /// Lime, for the main action on a screen.
  primary,

  /// Outlined, for the other actions.
  secondary,
}

/// Nova's text button: 48 px tall (52 when [large]), radius 16, or fully
/// round when [pill].
class NovaButton extends StatelessWidget {
  const NovaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = NovaButtonKind.primary,
    this.large = false,
    this.expand = false,
    this.pill = false,
    this.iconAfter = false,
  });

  const NovaButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.large = false,
    this.expand = false,
    this.pill = false,
    this.iconAfter = false,
  }) : kind = NovaButtonKind.secondary;

  final String label;

  /// Null shows the button as disabled.
  final VoidCallback? onPressed;
  final IconData? icon;
  final NovaButtonKind kind;

  /// 52 px tall, for the sign-in screen.
  final bool large;

  /// Fills the available width.
  final bool expand;

  /// Fully round ends (the onboarding buttons).
  final bool pill;

  /// The icon goes after the label ("Next →") instead of before it.
  final bool iconAfter;

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    final height = large ? NovaSize.buttonLarge : NovaSize.button;
    final size = Size(
      expand ? double.infinity : NovaSize.minTouchTarget,
      height,
    );
    final text = Text(label);
    final iconWidget = icon == null ? null : Icon(icon, size: NovaSize.icon);

    final shape = pill ? const StadiumBorder() : null;
    final iconAlignment = iconAfter ? IconAlignment.end : IconAlignment.start;

    final Widget button;
    if (kind == NovaButtonKind.primary) {
      final style = FilledButton.styleFrom(
        minimumSize: size,
        shape: shape,
        iconAlignment: iconAlignment,
        padding: pill
            ? const EdgeInsets.symmetric(horizontal: NovaSpace.xl)
            : null,
      );
      button = iconWidget == null
          ? FilledButton(onPressed: onPressed, style: style, child: text)
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: iconWidget,
              label: text,
            );
    } else {
      final style = OutlinedButton.styleFrom(
        minimumSize: size,
        side: BorderSide(color: c.fieldBorder),
        shape: shape,
        iconAlignment: iconAlignment,
      );
      button = iconWidget == null
          ? OutlinedButton(onPressed: onPressed, style: style, child: text)
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: style,
              icon: iconWidget,
              label: text,
            );
    }
    return button;
  }
}
