import 'package:flutter/material.dart';

/// The "Studio" colours that Material's ColorScheme has no slot for.
///
/// Read them with `NovaColors.of(context)`. Contrast of every text and icon
/// pair is checked in test/contrast_test.dart.
@immutable
class NovaColors extends ThemeExtension<NovaColors> {
  const NovaColors({
    required this.background,
    required this.panel,
    required this.mainPanel,
    required this.card,
    required this.cardRaised,
    required this.input,
    required this.control,
    required this.controlStrong,
    required this.outline,
    required this.fieldOutline,
    required this.fieldBorder,
    required this.selectedRow,
    required this.textPrimary,
    required this.textBody,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.accentHover,
    required this.accentTile,
    required this.error,
    required this.projectOrange,
    required this.projectOrangeTile,
    required this.projectOrangeLabel,
    required this.projectTeal,
    required this.projectTealTile,
  });

  /// The Studio palette (dark).
  static const studio = NovaColors(
    background: Color(0xFF121214),
    panel: Color(0xFF1E1E22),
    mainPanel: Color(0xFF18181B),
    card: Color(0xFF222226),
    cardRaised: Color(0xFF2B2B30),
    input: Color(0xFF26262B),
    control: Color(0xFF28282D),
    controlStrong: Color(0xFF34343A),
    outline: Color(0xFF3A3A40),
    fieldOutline: Color(0xFF45454C),
    // Borders of boxes you type in: lighter than the design's outline
    // colours so they reach 3:1 (agreed in the Round 1 questions).
    fieldBorder: Color(0xFF75757D),
    selectedRow: Color(0xFF2E2E33),
    textPrimary: Color(0xFFF4F1EA),
    textBody: Color(0xFFE6E2D9),
    textSecondary: Color(0xFFCFCBC2),
    textMuted: Color(0xFFA8A49B),
    accent: Color(0xFFD4F25C),
    onAccent: Color(0xFF121214),
    accentHover: Color(0xFFE6FA9A),
    accentTile: Color(0xFF262A1C),
    error: Color(0xFFFF8A80),
    projectOrange: Color(0xFFF2A65A),
    projectOrangeTile: Color(0xFF2A2620),
    projectOrangeLabel: Color(0xFFF2C391),
    projectTeal: Color(0xFF6FD3B8),
    projectTealTile: Color(0xFF1F2A27),
  );

  final Color background;
  final Color panel;
  final Color mainPanel;
  final Color card;
  final Color cardRaised;
  final Color input;
  final Color control;
  final Color controlStrong;

  /// Decoration only: outlined chips, dashed rows.
  final Color outline;

  /// Decoration only: the design's soft field outline.
  final Color fieldOutline;

  /// Borders of text fields and the composer (3:1 or more).
  final Color fieldBorder;
  final Color selectedRow;
  final Color textPrimary;
  final Color textBody;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color accentHover;
  final Color accentTile;
  final Color error;
  final Color projectOrange;
  final Color projectOrangeTile;
  final Color projectOrangeLabel;
  final Color projectTeal;
  final Color projectTealTile;

  static NovaColors of(BuildContext context) =>
      Theme.of(context).extension<NovaColors>() ?? studio;

  /// A project's colours. Picked from its id, so a project keeps the same
  /// colour forever, wherever it appears. Nothing is stored.
  ProjectColors forProject(String projectId) => stableHash(projectId).isEven
      ? ProjectColors(
          dot: projectOrange,
          tile: projectOrangeTile,
          label: projectOrangeLabel,
        )
      : ProjectColors(
          dot: projectTeal,
          tile: projectTealTile,
          label: projectTeal,
        );

  @override
  NovaColors copyWith() => this;

  @override
  NovaColors lerp(NovaColors? other, double t) => this;
}

/// The three colours used to show one project.
@immutable
class ProjectColors {
  const ProjectColors({
    required this.dot,
    required this.tile,
    required this.label,
  });

  final Color dot;
  final Color tile;
  final Color label;
}

/// FNV-1a hash of [text]: the same on every device and every run
/// (Dart's own `hashCode` doesn't promise that).
///
/// The multiply is done in 16-bit halves so it stays exact on the web,
/// where numbers above 2^53 lose precision.
int stableHash(String text) {
  const mod = 0x100000000; // 2^32
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = (hash ^ unit) % mod;
    final lo = hash & 0xFFFF, hi = hash >> 16;
    // hash * 0x01000193, keeping only the low 32 bits.
    hash =
        (lo * 0x0193 + ((hi * 0x0193 + lo * 0x0100) % 0x10000) * 0x10000) % mod;
  }
  return hash;
}
