// Studio redesign: every text and icon colour must be readable.
// Text needs a contrast of at least 4.5:1 with its background (3:1 for text
// 24 px and larger), icons and field borders at least 3:1 (WCAG AA).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/nova_colors.dart';

/// WCAG contrast ratio between two opaque colours (1 to 21).
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final l1 = lum(a), l2 = lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

const c = NovaColors.studio;

/// (what, foreground, background, minimum)
final pairs = <(String, Color, Color, double)>[
  // Main text
  ('Headings on main panel', c.textPrimary, c.mainPanel, 4.5),
  ('Headings on sidebar panel', c.textPrimary, c.panel, 4.5),
  ('Answer text on card', c.textBody, c.card, 4.5),
  ('Code on raised card', c.textBody, c.cardRaised, 4.5),
  ('Sidebar rows', c.textSecondary, c.panel, 4.5),
  ('Selected sidebar row', c.textPrimary, c.selectedRow, 4.5),
  ('Secondary text on main panel', c.textSecondary, c.mainPanel, 4.5),
  // Muted text
  ('Section labels on sidebar', c.textMuted, c.panel, 4.5),
  ('Disclaimer on main panel', c.textMuted, c.mainPanel, 4.5),
  ('Placeholder in composer', c.textMuted, c.input, 4.5),
  ('Muted text on card', c.textMuted, c.card, 4.5),
  ('Muted text on raised card', c.textMuted, c.cardRaised, 4.5),
  // Accent
  ('Text on lime buttons', c.onAccent, c.accent, 4.5),
  ('Lime text / links on main panel', c.accent, c.mainPanel, 4.5),
  ('Lime text on sidebar', c.accent, c.panel, 4.5),
  ('Lime link hover on main panel', c.accentHover, c.mainPanel, 4.5),
  ('Lime icon on accent tile', c.accent, c.accentTile, 3),
  ('Tooltip text', c.background, c.textPrimary, 4.5),
  // Projects
  (
    'Orange project label on its tile',
    c.projectOrangeLabel,
    c.projectOrangeTile,
    4.5,
  ),
  ('Teal project label on its tile', c.projectTeal, c.projectTealTile, 4.5),
  ('Orange project name on main panel', c.projectOrangeLabel, c.mainPanel, 4.5),
  ('Teal project name on main panel', c.projectTeal, c.mainPanel, 4.5),
  ('Avatar letter on orange', c.onAccent, c.projectOrange, 4.5),
  ('Orange dot on sidebar', c.projectOrange, c.panel, 3),
  ('Teal dot on sidebar', c.projectTeal, c.panel, 3),
  // Errors
  ('Error text on main panel', c.error, c.mainPanel, 4.5),
  ('Error text on sidebar / fields', c.error, c.panel, 4.5),
  ('Error text on card', c.error, c.card, 4.5),
  ('Error text on raised card', c.error, c.cardRaised, 4.5),
  // Icons and controls
  ('Muted icons (answer actions)', c.textMuted, c.mainPanel, 3),
  ('Muted icons on card', c.textMuted, c.card, 3),
  ('Icons on control buttons', c.textSecondary, c.control, 3),
  ('Icons on attach button', c.textPrimary, c.controlStrong, 3),
  ('Disabled Send icon', c.textMuted, c.controlStrong, 3),
  ('Lime Send button on composer', c.accent, c.input, 3),
  // Borders of things you type in
  ('Field border on sidebar / fields', c.fieldBorder, c.panel, 3),
  ('Composer border on composer', c.fieldBorder, c.input, 3),
  ('Field border on main panel', c.fieldBorder, c.mainPanel, 3),
  ('Focused border (lime) on panel', c.accent, c.panel, 3),
];

void main() {
  test('every Studio colour pair passes contrast', () {
    final failures = <String>[];
    for (final (label, fg, bg, min) in pairs) {
      final ratio = contrast(fg, bg);
      // ignore: avoid_print
      print('$label | ${ratio.toStringAsFixed(2)}:1 (min $min)');
      if (ratio < min) failures.add('$label (${ratio.toStringAsFixed(2)})');
    }
    expect(failures, isEmpty);
  });
}
