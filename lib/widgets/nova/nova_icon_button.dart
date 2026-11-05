import 'package:flutter/material.dart';

import '../../app/nova_colors.dart';
import '../../app/nova_tokens.dart';

enum NovaIconButtonKind {
  /// No background, muted icon (answer actions).
  plain,

  /// `control` background (sidebar and top bar buttons).
  control,

  /// `controlStrong` background (the attach button).
  strong,

  /// Lime background (Send, Stop, New chat on phones).
  accent,
}

enum NovaIconButtonShape { round, square }

/// Nova's icon-only button: 44 × 44, always with a tooltip (which is also
/// what screen readers announce).
class NovaIconButton extends StatelessWidget {
  const NovaIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.kind = NovaIconButtonKind.plain,
    this.shape = NovaIconButtonShape.round,
    this.isSelected,
    this.selectedIcon,
    this.iconSize = NovaSize.icon,
  });

  final IconData icon;
  final String tooltip;

  /// Null shows the button as disabled.
  final VoidCallback? onPressed;
  final NovaIconButtonKind kind;
  final NovaIconButtonShape shape;

  /// For on/off buttons (like thumbs up): shows [selectedIcon] in the accent
  /// colour when true.
  final bool? isSelected;
  final IconData? selectedIcon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    final (Color? bg, Color fg) = switch (kind) {
      NovaIconButtonKind.plain => (null, c.textMuted),
      NovaIconButtonKind.control => (c.control, c.textSecondary),
      NovaIconButtonKind.strong => (c.controlStrong, c.textPrimary),
      NovaIconButtonKind.accent => (c.accent, c.onAccent),
    };
    final OutlinedBorder border = shape == NovaIconButtonShape.round
        ? const CircleBorder()
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NovaRadius.row),
          );

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: isSelected,
      icon: Icon(icon),
      selectedIcon: selectedIcon == null ? null : Icon(selectedIcon),
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll(
          Size.square(NovaSize.iconButton),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size.square(NovaSize.minTouchTarget),
        ),
        // The button itself is the 44 px touch target, so no extra
        // invisible padding (which would space buttons wider than the design).
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        iconSize: WidgetStatePropertyAll(iconSize),
        shape: WidgetStatePropertyAll(border),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            // A disabled Send is grey, not lime.
            return bg == null ? null : c.controlStrong;
          }
          return bg;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.textMuted;
          if (states.contains(WidgetState.selected) &&
              kind == NovaIconButtonKind.plain) {
            return c.accent;
          }
          return fg;
        }),
      ),
    );
  }
}
