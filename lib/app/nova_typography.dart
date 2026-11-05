import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'nova_colors.dart';

/// Nova's type scale.
///
/// - Space Grotesk: the logo word, headings, titles, section labels.
/// - DM Sans: body text, buttons, inputs.
/// - DM Mono: code.
///
/// The font files are bundled in assets/google_fonts (nothing is
/// downloaded). Styles Material has no slot for are in [NovaText].
class NovaTypography {
  NovaTypography._();

  static TextStyle _heading(double size, FontWeight weight, Color color) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  static TextStyle _body(
    double size,
    FontWeight weight,
    Color color, {
    double height = 1.5,
  }) => GoogleFonts.dmSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  /// Letter spacing of -0.035em for the big display text.
  static double _tight(double size) => -0.035 * size;

  /// Material's text slots, mapped to the Studio scale.
  static TextTheme textTheme(NovaColors c) => TextTheme(
    displayLarge: _heading(
      60,
      FontWeight.w600,
      c.textPrimary,
    ).copyWith(letterSpacing: _tight(60), height: 1.05),
    displayMedium: _heading(
      52,
      FontWeight.w600,
      c.textPrimary,
    ).copyWith(letterSpacing: _tight(52), height: 1.05),
    displaySmall: _heading(
      46,
      FontWeight.w600,
      c.textPrimary,
    ).copyWith(letterSpacing: _tight(46), height: 1.1),
    headlineLarge: _heading(34, FontWeight.w600, c.textPrimary),
    headlineMedium: _heading(28, FontWeight.w600, c.textPrimary),
    headlineSmall: _heading(24, FontWeight.w600, c.textPrimary),
    titleLarge: _heading(20, FontWeight.w600, c.textPrimary),
    titleMedium: _heading(15, FontWeight.w600, c.textPrimary),
    titleSmall: _heading(14, FontWeight.w600, c.textPrimary),
    bodyLarge: _body(16, FontWeight.w400, c.textPrimary),
    bodyMedium: _body(15, FontWeight.w400, c.textPrimary),
    bodySmall: _body(13, FontWeight.w400, c.textSecondary),
    labelLarge: _body(15, FontWeight.w600, c.textPrimary, height: 1.2),
    labelMedium: _body(13, FontWeight.w500, c.textSecondary, height: 1.3),
    labelSmall: _body(12, FontWeight.w500, c.textMuted, height: 1.3),
  );

  /// The extra styles.
  static NovaText extra(NovaColors c) => NovaText(
    logo: _heading(21, FontWeight.w700, c.textPrimary),
    onboardingDisplay: _heading(
      56,
      FontWeight.w600,
      c.textPrimary,
    ).copyWith(letterSpacing: _tight(56), height: 1.05),
    splashWordmark: _heading(
      44,
      FontWeight.w700,
      c.textPrimary,
    ).copyWith(letterSpacing: _tight(44), height: 1.1),
    cardTitle: _heading(15, FontWeight.w600, c.textPrimary),
    tileTitle: _heading(13.5, FontWeight.w600, c.textPrimary),
    sectionLabel: _heading(
      12,
      FontWeight.w600,
      c.textMuted,
    ).copyWith(letterSpacing: 1.2),
    body: _body(15.5, FontWeight.w400, c.textBody, height: 1.7),
    row: _body(14, FontWeight.w400, c.textSecondary, height: 1.3),
    rowSelected: _body(14, FontWeight.w600, c.textPrimary, height: 1.3),
    small: _body(13, FontWeight.w500, c.textSecondary, height: 1.4),
    caption: _body(12, FontWeight.w400, c.textMuted, height: 1.4),
    code: GoogleFonts.dmMono(
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      color: c.textBody,
      height: 1.55,
    ),
  );
}

/// Text styles Material's TextTheme has no slot for.
/// Read them with `NovaText.of(context)`.
@immutable
class NovaText extends ThemeExtension<NovaText> {
  const NovaText({
    required this.logo,
    required this.splashWordmark,
    required this.onboardingDisplay,
    required this.cardTitle,
    required this.tileTitle,
    required this.sectionLabel,
    required this.body,
    required this.row,
    required this.rowSelected,
    required this.small,
    required this.caption,
    required this.code,
  });

  /// The lowercase "nova" next to the logo.
  final TextStyle logo;

  /// The big lowercase "nova" on the splash screen.
  final TextStyle splashWordmark;

  /// The welcome tour's heading on wide screens.
  final TextStyle onboardingDisplay;

  /// Suggestion and project card titles.
  final TextStyle cardTitle;

  /// Project names on the small sidebar tiles.
  final TextStyle tileTitle;

  /// "PROJECTS", "RECENT". Show the text in upper case.
  final TextStyle sectionLabel;

  /// Answers and messages.
  final TextStyle body;

  /// Sidebar chat rows (and the selected row).
  final TextStyle row;
  final TextStyle rowSelected;

  /// Chips and card descriptions.
  final TextStyle small;

  /// The disclaimer, the email under the name.
  final TextStyle caption;

  /// Inline code and code blocks.
  final TextStyle code;

  static NovaText of(BuildContext context) =>
      Theme.of(context).extension<NovaText>() ??
      NovaTypography.extra(NovaColors.studio);

  @override
  NovaText copyWith() => this;

  @override
  NovaText lerp(NovaText? other, double t) => this;
}
