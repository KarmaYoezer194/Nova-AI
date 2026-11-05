/// Nova's "Studio" design tokens: spacing, corner radii and sizes.
///
/// Widgets take their measurements from here (and colours and text styles
/// from the theme), so the look can change in one place.
library;

/// The spacing scale.
class NovaSpace {
  NovaSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Padding around the whole app and the gap between panels.
  static const double appPadding = md;
  static const double panelGap = md;

  /// Padding inside Nova's answer cards (vertical, horizontal).
  static const double cardPaddingV = 22;
  static const double cardPaddingH = xl;
}

/// Corner radii.
class NovaRadius {
  NovaRadius._();

  /// Small thumbnails and icons inside tiles.
  static const double xs = 6;
  static const double sm = 8;

  /// Sidebar rows and text fields.
  static const double row = 14;
  static const double field = 14;

  /// Buttons and project tiles.
  static const double button = 16;

  /// Suggestion cards.
  static const double suggestion = 20;

  /// Panels, answer cards and user bubbles.
  static const double panel = 22;
  static const double card = 22;
  static const double bubble = 22;

  /// The user bubble's bottom-right corner.
  static const double bubbleTail = 6;

  /// The big composer on the new-chat screen.
  static const double composerLarge = 26;

  /// The chat composer: round at one line (56 px tall), and still softly
  /// rounded when it grows to several lines.
  static const double composer = 28;

  /// Fully round: chips, round buttons, the chat composer.
  static const double pill = 999;
}

/// Fixed sizes.
class NovaSize {
  NovaSize._();

  static const double sidebarWidth = 288;
  static const double chatMaxWidth = 740;

  /// Primary buttons (52 on the sign-in screen).
  static const double button = 48;
  static const double buttonLarge = 52;

  /// Icon buttons, and the smallest touch target anywhere.
  static const double iconButton = 44;
  static const double minTouchTarget = 44;

  /// Chips are drawn this tall; their touch area is still 44+.
  static const double chip = 36;

  /// Icons.
  static const double iconSmall = 17;
  static const double icon = 18;
  static const double iconLarge = 20;

  /// Project colour squares (tiles, pills) and the small lime dot on the
  /// selected chat.
  static const double swatch = 12;

  /// The bigger colour square on a sidebar project tile.
  static const double projectSquare = 20;
  static const double swatchSmall = 8;
  static const double dot = 6;

  /// The welcome tour's step dots: 8 × 8, the current one 24 × 8.
  static const double stepDot = 8;
  static const double stepDotActive = 24;

  /// The account avatar.
  static const double avatar = 36;

  /// The logo in the sidebar, next to answers, and on the new-chat screen.
  static const double logoSidebar = 32;
  static const double logoAnswer = 22;
  static const double logoHero = 44;

  /// The splash screen: the logo, and the orbit rings around it.
  static const double splashLogo = 96;
  static const double splashOrbits = 220;

  /// The logo on the native splash (drawn by the system before Flutter
  /// starts). The Flutter splash's first frame shows the logo at exactly
  /// this size, then grows it to [splashLogo].
  static const double nativeSplashLogo = 82;
}
