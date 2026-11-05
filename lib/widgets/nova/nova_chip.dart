import 'package:flutter/material.dart';

import '../../app/nova_colors.dart';
import '../../app/nova_tokens.dart';
import '../../app/nova_typography.dart';

/// A fully round, outlined pill (for example the project label).
///
/// Drawn 36 px tall, but its touch area is 48 px (Material's padded tap
/// target), so it's easy to hit.
class NovaChip extends StatelessWidget {
  const NovaChip({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.selected = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Accent colours when on.
  final bool selected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    final style = NovaText.of(context).small;
    final fg = selected ? c.accent : c.textSecondary;

    final chip = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        backgroundColor: selected ? c.accentTile : null,
        side: BorderSide(color: selected ? c.accent : c.outline),
        shape: const StadiumBorder(),
        minimumSize: const Size(NovaSize.chip, NovaSize.chip),
        padding: const EdgeInsets.symmetric(horizontal: NovaSpace.md),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: style,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: NovaSize.iconSmall),
            const SizedBox(width: NovaSpace.sm - 2),
          ],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
  }
}
