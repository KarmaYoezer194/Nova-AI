import '../services/account_service.dart';
import '../services/ai_service.dart';
import '../services/artifact_repository.dart';
import '../services/auth_service.dart';
import '../services/chat_repository.dart';
import '../services/feedback_repository.dart';
import '../services/memory_repository.dart';
import '../services/project_repository.dart';
import '../services/saved_repository.dart';

/// All the app's services in one bundle, created once in main.dart and
/// passed down to the screens. Adding a service later means changing this
/// class, not every screen in between.
///
/// (Remote Config is read once at start-up in main.dart and handed to the
/// AI service, so screens don't need it.)
class AppServices {
  const AppServices({
    required this.auth,
    required this.chat,
    required this.ai,
    required this.memory,
    required this.projects,
    required this.artifacts,
    required this.account,
    required this.saved,
    required this.feedback,
  });

  /// Thumbs up / down on answers (UI round 2).
  final FeedbackRepository feedback;

  /// Saved (bookmarked) answers (UI round 1).
  final SavedRepository saved;

  /// Account and data deletion (Phase 12).
  final AccountService account;

  /// Artifact versions (Phase 10).
  final ArtifactRepository artifacts;

  /// Projects (Phase 9).
  final ProjectRepository projects;

  final AuthService auth;
  final ChatRepository chat;
  final AiService ai;

  /// Custom instructions and memories (Phase 8).
  final MemoryRepository memory;
}
