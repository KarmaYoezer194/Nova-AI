/// App-wide constants.
///
/// The assistant's name lives here and only here, so renaming Nova later
/// means changing one line.
class AppConstants {
  AppConstants._(); // Not meant to be created; just a namespace.

  /// The assistant's display name, used everywhere in the UI.
  static const String assistantName = 'Nova';

  /// The app's name (browser tab, app switcher).
  static const String appName = 'Nova';

  /// Shown under the input box (security rule 7).
  static const String disclaimer =
      '$assistantName can make mistakes. Don\'t share private information.';

  /// Example prompts on an empty chat.
  static const List<String> examplePrompts = [
    'Explain how the internet works, simply',
    'Help me plan a study timetable for exams',
    'Give me 5 ideas for a weekend project',
  ];

  // ---------- Limits (security rule 4) ----------
  // firestore.rules has its own, looser limits (20,000 for user messages,
  // 100,000 for model messages). The app's limit is stricter on purpose, so
  // normal use never hits the rules.

  /// Longest message a user can type.
  static const int maxUserMessageLength = 4000;

  /// Longest model answer we store (matches firestore.rules).
  static const int maxModelMessageLength = 100000;

  /// Longest conversation title we store.
  static const int maxTitleLength = 100;

  /// Longest title Nova suggests for a new chat.
  static const int maxSuggestedTitleLength = 60;

  /// Length of the answer preview kept for a saved answer.
  static const int maxSavedPreviewLength = 300;

  /// How many of a chat's newest messages we load from Firestore.
  static const int maxLoadedMessages = 50;

  /// How many past messages we send to the AI as history.
  static const int maxHistoryMessages = 20;

  /// Largest file a user can attach (7 MB). Files are sent inside the
  /// request, which grows by about a third in transit, so this stays well
  /// under the AI service's 20 MB request limit.
  static const int maxAttachmentBytes = 7 * 1024 * 1024;

  /// Longest attachment file name we store (matches firestore.rules).
  static const int maxAttachmentNameLength = 120;

  /// Sent as the question when the user attaches a file but types nothing.
  static const String defaultAttachmentQuestion =
      'Please explain what is in this file.';

  // ---------- Personalization (Phase 8) ----------
  // Everything here is sent with EVERY message, so it is kept small.
  // firestore.rules allows a bit more (2,000 and 500), like the other limits.

  /// Longest "What should Nova know about you?" text.
  static const int maxCustomInstructionsLength = 1500;

  /// Longest single memory.
  static const int maxMemoryLength = 200;

  /// Most memories a user can keep. Only the newest this many are ever
  /// loaded or sent, whatever is in the database.
  static const int maxMemories = 30;

  // ---------- Projects (Phase 9) ----------
  // A project's instructions and notes are sent with EVERY message in its
  // chats, so they are limited. firestore.rules allows a bit more
  // (100, 2,000 and 10,000).

  static const int maxProjectNameLength = 60;
  static const int maxProjectInstructionsLength = 1500;

  /// About 1,500 tokens: enough for a syllabus or a brief.
  static const int maxProjectNotesLength = 6000;

  /// Most projects a user can have. Only this many are ever loaded.
  static const int maxProjects = 20;

  // ---------- Layout ----------

  /// At this width or wider, the sidebar is always visible.
  static const double wideLayoutBreakpoint = 900;

  /// Readable width of the chat column on wide screens.
  static const double maxChatWidth = 720;

  /// The message box grows up to this many lines, then scrolls inside.
  static const int maxInputLines = 6;
}
