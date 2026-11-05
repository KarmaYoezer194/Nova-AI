import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Every icon in the app, from one set (Lucide, outline style).
///
/// Named by what they do, so a screen asks for `NovaIcons.send`, not a
/// specific drawing. Swap a drawing here and it changes everywhere.
class NovaIcons {
  NovaIcons._();

  // Chat
  static const IconData send = LucideIcons.arrowUp;
  static const IconData stop = LucideIcons.square;
  static const IconData attach = LucideIcons.paperclip;
  static const IconData newChat = LucideIcons.squarePen;
  static const IconData chat = LucideIcons.messageCircle;
  static const IconData jumpToLatest = LucideIcons.arrowDown;
  static const IconData link = LucideIcons.link;
  static const IconData searchingTools = LucideIcons.fileSearch;

  // Answer actions
  static const IconData copy = LucideIcons.copy;
  static const IconData save = LucideIcons.bookmark;
  static const IconData saved = LucideIcons.bookmarkCheck;
  static const IconData remember = LucideIcons.lightbulb;
  static const IconData thumbUp = LucideIcons.thumbsUp;
  static const IconData thumbDown = LucideIcons.thumbsDown;
  static const IconData regenerate = LucideIcons.refreshCw;
  static const IconData edit = LucideIcons.pencil;

  // General
  static const IconData add = LucideIcons.plus;
  static const IconData close = LucideIcons.x;
  static const IconData check = LucideIcons.check;
  static const IconData more = LucideIcons.ellipsis;
  static const IconData search = LucideIcons.search;
  static const IconData delete = LucideIcons.trash2;
  static const IconData deleteForever = LucideIcons.trash;
  static const IconData share = LucideIcons.share2;
  static const IconData openExternal = LucideIcons.externalLink;
  static const IconData expandMore = LucideIcons.chevronDown;
  static const IconData expandLess = LucideIcons.chevronUp;
  static const IconData dropdown = LucideIcons.chevronDown;
  static const IconData showPassword = LucideIcons.eye;
  static const IconData hidePassword = LucideIcons.eyeOff;

  // Navigation
  static const IconData menu = LucideIcons.menu;
  static const IconData back = LucideIcons.arrowLeft;
  static const IconData collapseSidebar = LucideIcons.panelLeft;
  static const IconData next = LucideIcons.arrowRight;
  static const IconData skip = LucideIcons.chevronRight;
  static const IconData welcomeTour = LucideIcons.compass;
  static const IconData account = LucideIcons.slidersHorizontal;

  // New-chat suggestions
  static const IconData explain = LucideIcons.lightbulb;
  static const IconData calendar = LucideIcons.calendar;
  static const IconData ideas = LucideIcons.sparkles;

  // Places and things
  static const IconData folder = LucideIcons.folder;
  static const IconData moveToProject = LucideIcons.folderInput;
  static const IconData settings = LucideIcons.settings;
  static const IconData signOut = LucideIcons.logOut;
  static const IconData privacy = LucideIcons.shieldCheck;
  static const IconData deleteAccount = LucideIcons.userMinus;
  static const IconData image = LucideIcons.image;
  static const IconData pdf = LucideIcons.fileText;
  static const IconData document = LucideIcons.fileText;
  static const IconData code = LucideIcons.code;
}
