import 'package:flutter/material.dart';

import 'nova_colors.dart';
import 'nova_icons.dart';
import 'nova_tokens.dart';
import 'nova_typography.dart';

/// Nova's "Studio" theme (dark only for now).
///
/// Colours come from [NovaColors.studio], text from [NovaTypography], and
/// sizes from nova_tokens.dart. Widgets read them from here instead of
/// hard-coding their own. Contrast is checked by test/contrast_test.dart.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(NovaColors.studio);

  static ThemeData _build(NovaColors c) {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentTile,
      onPrimaryContainer: c.accent,
      secondary: c.textSecondary,
      onSecondary: c.onAccent,
      // Selected rows and tiles.
      secondaryContainer: c.selectedRow,
      onSecondaryContainer: c.textPrimary,
      tertiary: c.projectTeal,
      onTertiary: c.onAccent,
      tertiaryContainer: c.projectTealTile,
      onTertiaryContainer: c.projectTeal,
      error: c.error,
      onError: c.onAccent,
      errorContainer: c.cardRaised,
      onErrorContainer: c.error,
      surface: c.mainPanel,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textMuted,
      surfaceDim: c.background,
      surfaceBright: c.cardRaised,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.panel,
      surfaceContainer: c.card,
      surfaceContainerHigh: c.input,
      surfaceContainerHighest: c.cardRaised,
      // Borders of things you type in or tap: 3:1 or more.
      outline: c.fieldBorder,
      outlineVariant: c.fieldBorder,
      shadow: c.background,
      scrim: c.background,
      inverseSurface: c.textPrimary,
      onInverseSurface: c.background,
      inversePrimary: c.accentTile,
      surfaceTint: Colors.transparent,
    );
    final text = NovaTypography.textTheme(c);
    final extra = NovaTypography.extra(c);

    RoundedRectangleBorder rounded(double r) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: text,
      extensions: [c, extra],
      scaffoldBackgroundColor: c.mainPanel,
      canvasColor: c.mainPanel,
      // Dividers only separate areas (they aren't controls), so they can
      // be soft.
      dividerTheme: DividerThemeData(color: c.controlStrong, space: 1),
      iconTheme: IconThemeData(color: c.textSecondary, size: NovaSize.icon),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          iconSize: const WidgetStatePropertyAll(NovaSize.icon),
          minimumSize: const WidgetStatePropertyAll(
            Size.square(NovaSize.minTouchTarget),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.textMuted
                : null, // Everything else: the button's own colours.
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.controlStrong,
          disabledForegroundColor: c.textMuted,
          minimumSize: const Size(NovaSize.minTouchTarget, NovaSize.button),
          padding: const EdgeInsets.symmetric(horizontal: NovaSpace.xl),
          textStyle: text.labelLarge,
          shape: rounded(NovaRadius.button),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          disabledForegroundColor: c.textMuted,
          side: BorderSide(color: c.fieldBorder),
          minimumSize: const Size(NovaSize.minTouchTarget, NovaSize.button),
          padding: const EdgeInsets.symmetric(horizontal: NovaSpace.xl),
          textStyle: text.labelLarge,
          shape: rounded(NovaRadius.button),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          minimumSize: const Size(
            NovaSize.minTouchTarget,
            NovaSize.minTouchTarget,
          ),
          textStyle: text.labelLarge,
          shape: rounded(NovaRadius.button),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.mainPanel,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: c.panel),
      // Flutter's own menu and back buttons use Nova's icons too (their
      // tooltips, like "Open navigation menu" and "Back", stay the same).
      actionIconTheme: ActionIconThemeData(
        drawerButtonIconBuilder: (_) => const Icon(NovaIcons.menu),
        backButtonIconBuilder: (_) => const Icon(NovaIcons.back),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textSecondary,
        selectedColor: c.textPrimary,
        selectedTileColor: c.selectedRow,
        shape: rounded(NovaRadius.row),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: rounded(NovaRadius.card),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.mainPanel,
        side: BorderSide(color: c.fieldBorder),
        labelStyle: extra.small,
        shape: rounded(NovaRadius.pill),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.panel,
        shape: rounded(NovaRadius.panel),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.cardRaised,
        textStyle: text.bodyMedium,
        shape: rounded(NovaRadius.row),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.cardRaised,
        contentTextStyle: text.bodyMedium,
        actionTextColor: c.accent,
        behavior: SnackBarBehavior.floating,
        shape: rounded(NovaRadius.row),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.textPrimary,
          borderRadius: BorderRadius.circular(NovaRadius.sm),
        ),
        textStyle: text.labelMedium?.copyWith(color: c.background),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onAccent : c.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.controlStrong,
        ),
        trackOutlineColor: WidgetStatePropertyAll(c.fieldBorder),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.35),
        selectionHandleColor: c.accent,
      ),
      // Text fields: labels above or inside, 1 px border at rest, 2 px
      // accent when focused, error colour (with text) on mistakes.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.panel,
        hintStyle: text.bodyMedium?.copyWith(color: c.textMuted),
        labelStyle: text.bodyMedium?.copyWith(color: c.textMuted),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: c.accent),
        helperStyle: extra.caption,
        errorStyle: extra.caption.copyWith(color: c.error),
        counterStyle: extra.caption,
        prefixIconColor: c.textMuted,
        suffixIconColor: c.textMuted,
        // Only the shape: Material then draws it 1 px in `outline`
        // (fieldBorder) at rest, 2 px in `primary` (accent) when focused,
        // and in `error` on mistakes. Fields that set `border: none` (the
        // chat input) stay borderless.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NovaRadius.field),
        ),
      ),
    );
  }
}
