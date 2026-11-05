// Stand-ins for the real services, so widget tests run without Firebase
// or the internet.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:nova_chat/services/device_prefs.dart';

import 'package:nova_chat/app/app_services.dart';
import 'package:nova_chat/models/artifact.dart';
import 'package:nova_chat/models/attachment.dart';
import 'package:nova_chat/services/artifact_repository.dart';
import 'package:nova_chat/models/chat_message.dart';
import 'package:nova_chat/models/conversation.dart';
import 'package:nova_chat/models/memory.dart';
import 'package:nova_chat/models/project.dart';
import 'package:nova_chat/models/saved_item.dart';
import 'package:nova_chat/services/memory_repository.dart';
import 'package:nova_chat/services/project_repository.dart';
import 'package:nova_chat/services/tools.dart';
import 'package:nova_chat/services/account_service.dart';
import 'package:nova_chat/services/ai_service.dart';
import 'package:nova_chat/services/auth_service.dart';
import 'package:nova_chat/services/chat_repository.dart';
import 'package:nova_chat/services/saved_repository.dart';
import 'package:nova_chat/services/feedback_repository.dart';

class FakeChatRepository extends ChatRepository {
  FakeChatRepository({this.chats = const []});

  final List<Conversation> chats;
  final messages = StreamController<List<ChatMessage>>.broadcast();

  String? createdTitle;
  final saved = <(MessageRole, String)>[];

  /// When true, each saved message is pushed to [messages] at once, like
  /// Firestore's instant local update.
  bool emitOnSave = false;
  List<ChatMessage> _current = [];

  /// If set, saving a user message waits for this, like waiting for the
  /// server to confirm the write.
  Completer<void>? userSaveGate;

  @override
  Stream<List<Conversation>> watchConversations(
    String uid, {
    int limit = 100,
  }) => Stream.value(chats);

  @override
  Stream<List<ChatMessage>> watchMessages(String uid, String conversationId) =>
      messages.stream;

  String? createdProjectId;

  @override
  Future<String> createConversation(
    String uid, {
    required String title,
    String? projectId,
  }) async {
    createdTitle = title;
    createdProjectId = projectId;
    return 'new-chat-id';
  }

  @override
  Future<String> addMessage({
    required String uid,
    required String conversationId,
    required MessageRole role,
    required String text,
    AttachmentKind? attachmentKind,
    String? attachmentName,
  }) async {
    saved.add((role, text));
    lastAttachmentKind = attachmentKind;
    lastAttachmentName = attachmentName;
    if (emitOnSave) {
      _current = [
        ..._current,
        ChatMessage(id: 'm${saved.length}', role: role, text: text),
      ];
      messages.add(_current);
    }
    if (role == MessageRole.user && userSaveGate != null) {
      await userSaveGate!.future;
    }
    return 'm${saved.length}';
  }

  AttachmentKind? lastAttachmentKind;
  String? lastAttachmentName;

  /// Records each search: (uid, query, excluded chat).
  final searches = <(String, String, String?)>[];

  @override
  Future<List<ChatSearchHit>> searchChats(
    String uid,
    String query, {
    String? excludeConversationId,
  }) async {
    searches.add((uid, query, excludeConversationId));
    return const [ChatSearchHit(title: 'Essay outline', preview: 'User: hi')];
  }

  @override
  Future<void> deleteConversation(String uid, String conversationId) async {}

  /// Records each Regenerate / Edit delete: (chat id, message ids).
  final deletedMessages = <(String, List<String>)>[];

  @override
  Future<void> deleteMessages(
    String uid,
    String conversationId,
    List<String> messageIds,
  ) async => deletedMessages.add((conversationId, messageIds));

  /// Records each move: (chat id, project id or null).
  final moves = <(String, String?)>[];

  @override
  Future<void> moveConversation(
    String uid,
    String conversationId,
    String? projectId,
  ) async => moves.add((conversationId, projectId));

  /// Records each rename: (chat id, new title).
  final renames = <(String, String)>[];

  @override
  Future<void> renameConversation(
    String uid,
    String conversationId,
    String title,
  ) async => renames.add((conversationId, title));
}

class FakeFeedbackRepository extends FeedbackRepository {
  /// Each change: (message id, rating, replacing) or (message id, null) for
  /// a removal.
  final changes = <(String, Rating?, bool)>[];

  @override
  Stream<Map<String, Rating>> watchIn(String uid, String conversationId) =>
      const Stream.empty();

  @override
  Future<void> rate({
    required String uid,
    required String conversationId,
    required String messageId,
    required Rating rating,
    bool replacing = false,
  }) async => changes.add((messageId, rating, replacing));

  @override
  Future<void> remove(
    String uid,
    String conversationId,
    String messageId,
  ) async => changes.add((messageId, null, false));
}

class FakeSavedRepository extends SavedRepository {
  /// Saved answers: (chat id, message id, title, answer).
  final saved = <(String, String, String, String)>[];
  final removed = <(String, String)>[];
  final _ids = StreamController<Set<String>>.broadcast();

  @override
  Stream<List<SavedItem>> watchSaved(String uid) => Stream.value([
    for (final (c, m, t, a) in saved)
      SavedItem(conversationId: c, messageId: m, title: t, preview: a),
  ]);

  @override
  Stream<Set<String>> watchSavedIn(String uid, String conversationId) =>
      _ids.stream;

  @override
  Future<void> save({
    required String uid,
    required String conversationId,
    required String messageId,
    required String chatTitle,
    required String answer,
  }) async => saved.add((conversationId, messageId, chatTitle, answer));

  @override
  Future<void> remove(
    String uid,
    String conversationId,
    String messageId,
  ) async => removed.add((conversationId, messageId));
}

class FakeMemoryRepository extends MemoryRepository {
  FakeMemoryRepository({this.personalization = Personalization.empty});

  Personalization personalization;
  final added = <String>[];

  @override
  Future<Personalization> loadPersonalization(String uid) async =>
      personalization;

  @override
  Future<void> addMemory(String uid, String text) async => added.add(text);

  @override
  Future<String> loadCustomInstructions(String uid) async =>
      personalization.customInstructions;

  @override
  Stream<List<Memory>> watchMemories(String uid) => Stream.value(const []);

  @override
  void preload(String uid) {}

  @override
  void stopWatching() {}
}

class FakeProjectRepository extends ProjectRepository {
  FakeProjectRepository({this.projects = const []});

  final List<Project> projects;

  @override
  Stream<List<Project>> watchProjects(String uid) => Stream.value(projects);

  @override
  Future<Project?> loadProject(String uid, String projectId) async {
    for (final p in projects) {
      if (p.id == projectId) return p;
    }
    return null;
  }
}

class FakeArtifactRepository extends ArtifactRepository {
  final saved = <ArtifactBlock>[];

  @override
  Stream<List<ArtifactVersion>> watchVersions(
    String uid,
    String conversationId,
    String key,
  ) => Stream.value(const []);

  @override
  Future<void> saveVersions({
    required String uid,
    required String conversationId,
    required String messageId,
    required List<ArtifactBlock> blocks,
  }) async => saved.addAll(blocks);
}

class FakeAccountService extends AccountService {
  FakeAccountService(AuthService auth, {this.error}) : super(auth: auth);

  /// If set, deleting fails with this.
  final Object? error;
  final deleted = <(String, String)>[];

  @override
  Future<void> deleteAccountAndData(String uid, String password) async {
    if (error != null) throw error!;
    deleted.add((uid, password));
  }
}

class FakeAiService extends AiService {
  /// Answers with [pieces], or with [controller]'s stream if given (lets a
  /// test keep the answer "streaming" until it decides otherwise).
  FakeAiService({this.pieces = const ['Hel', 'lo'], this.controller});

  final List<String> pieces;
  final StreamController<String>? controller;
  List<ChatMessage>? lastHistory;
  Attachment? lastAttachment;
  Personalization? lastPersonalization;
  Project? lastProject;
  NovaTools? lastTools;
  bool? lastNews;

  /// What [suggestTitle] returns (null = title generation failed).
  String? title;
  final titleRequests = <(String, String)>[];

  @override
  Future<String?> suggestTitle(String question, String answer) async {
    titleRequests.add((question, answer));
    return title;
  }

  @override
  Stream<String> streamReply({
    required List<ChatMessage> history,
    required String userText,
    Attachment? attachment,
    Personalization personalization = Personalization.empty,
    Project? project,
    NovaTools? tools,
    bool news = false,
    DateTime? now,
  }) {
    lastTools = tools;
    lastNews = news;
    lastHistory = history;
    lastAttachment = attachment;
    lastPersonalization = personalization;
    lastProject = project;
    return controller?.stream ?? Stream.fromIterable(pieces);
  }
}

AppServices fakeServices({
  FakeChatRepository? chat,
  FakeAiService? ai,
  FakeMemoryRepository? memory,
  FakeProjectRepository? projects,
  FakeArtifactRepository? artifacts,
  FakeAccountService? account,
  FakeSavedRepository? saved,
  FakeFeedbackRepository? feedback,
  AuthService? auth,
}) {
  // The real one only touches Firebase if a method is called.
  auth ??= AuthService();
  return AppServices(
    auth: auth,
    account: account ?? FakeAccountService(auth),
    chat: chat ?? FakeChatRepository(),
    ai: ai ?? FakeAiService(),
    memory: memory ?? FakeMemoryRepository(),
    projects: projects ?? FakeProjectRepository(),
    artifacts: artifacts ?? FakeArtifactRepository(),
    saved: saved ?? FakeSavedRepository(),
    feedback: feedback ?? FakeFeedbackRepository(),
  );
}

/// Always signed out, without Firebase.
class FakeSignedOutAuth extends AuthService {
  @override
  Stream<User?> authStateChanges() => Stream.value(null);

  @override
  User? get currentUser => null;
}

/// Device settings kept in memory.
class FakeDevicePrefs extends DevicePrefs {
  FakeDevicePrefs({this.onboarding = false, this.intro = false});

  bool onboarding;
  bool intro;

  @override
  Future<bool> onboardingSeen() async => onboarding;

  @override
  Future<void> setOnboardingSeen() async => onboarding = true;

  @override
  Future<bool> splashIntroSeen() async => intro;

  @override
  Future<void> setSplashIntroSeen() async => intro = true;
}
