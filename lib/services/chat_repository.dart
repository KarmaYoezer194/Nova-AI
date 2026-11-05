import 'package:cloud_firestore/cloud_firestore.dart';

import '../app/constants.dart';
import '../models/artifact.dart';
import '../models/attachment.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'tools.dart';

/// Thrown when the app tries to save something that breaks our limits.
class InvalidMessageException implements Exception {
  const InvalidMessageException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The only class that reads and writes chat data in Firestore.
///
/// Every path starts with users/{uid}, matching firestore.rules: a user can
/// only reach their own data. The rules enforce this on the server; this
/// class just never asks for anything else.
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore}) : _dbOverride = firestore;

  final FirebaseFirestore? _dbOverride;

  // Looked up only when first used, so screens can be tested without Firebase.
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _conversations(String uid) =>
      _db.collection('users').doc(uid).collection('conversations');

  CollectionReference<Map<String, dynamic>> _messages(
    String uid,
    String conversationId,
  ) => _conversations(uid).doc(conversationId).collection('messages');

  // ---------- Conversations ----------

  /// The user's chats, newest activity first. Updates live.
  Stream<List<Conversation>> watchConversations(String uid, {int limit = 100}) {
    return _conversations(uid)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Conversation.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Creates a chat (inside a project if [projectId] is set) and returns
  /// its id.
  Future<String> createConversation(
    String uid, {
    required String title,
    String? projectId,
  }) async {
    final doc = _conversations(uid).doc(); // Firestore picks a random id.
    await doc.set({
      'title': cleanTitle(title),
      'projectId': ?projectId, // Only added when set.
      'answered': false, // Hidden from the chat list until Nova answers.
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Gives a chat a new title (Nova's suggested title after the first
  /// answer).
  Future<void> renameConversation(
    String uid,
    String conversationId,
    String title,
  ) {
    return _conversations(uid).doc(conversationId).update({
      'title': cleanTitle(title),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Moves a chat into a project, or out of any project when [projectId]
  /// is null.
  Future<void> moveConversation(
    String uid,
    String conversationId,
    String? projectId,
  ) {
    return _conversations(uid).doc(conversationId).update({
      'projectId': projectId ?? FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes some messages of a chat (Regenerate and Edit remove the latest
  /// question and/or answer), with anything attached to them: their saved
  /// bookmark, rating and artifact versions. All in one batch.
  Future<void> deleteMessages(
    String uid,
    String conversationId,
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return;
    final user = _db.collection('users').doc(uid);
    final chat = _conversations(uid).doc(conversationId);
    final batch = _db.batch();
    for (final id in messageIds) {
      batch.delete(_messages(uid, conversationId).doc(id));
      batch.delete(user.collection('saved').doc('${conversationId}_$id'));
      batch.delete(user.collection('feedback').doc('${conversationId}_$id'));
      final versions = await chat
          .collection('artifacts')
          .where('messageId', isEqualTo: id)
          .get();
      for (final v in versions.docs) {
        batch.delete(v.reference);
      }
    }
    await batch.commit();
  }

  /// Deletes a chat with all its messages, artifact versions, saved
  /// answers and ratings.
  ///
  /// Firestore does not delete sub-collections automatically, so we delete
  /// them in batches first, then the chat itself.
  Future<void> deleteConversation(String uid, String conversationId) async {
    final chat = _conversations(uid).doc(conversationId);
    for (final sub in ['messages', 'artifacts']) {
      final collection = chat.collection(sub);
      while (true) {
        final page = await collection.limit(200).get();
        if (page.docs.isEmpty) break;
        final batch = _db.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    // Saved answers and ratings from this chat would point at nothing.
    for (final sub in ['saved', 'feedback']) {
      final linked = await _db
          .collection('users')
          .doc(uid)
          .collection(sub)
          .where('conversationId', isEqualTo: conversationId)
          .get();
      if (linked.docs.isEmpty) continue;
      final batch = _db.batch();
      for (final doc in linked.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await chat.delete();
  }

  /// For Nova's "search my chats" tool: finds the user's own chats whose
  /// titles match [query], with a short preview of how each chat started.
  ///
  /// Read-only, and only under users/{uid}. Kept small to save Firestore
  /// reads (Spark plan): 100 titles, then 2 messages for each of up to 5
  /// matches.
  Future<List<ChatSearchHit>> searchChats(
    String uid,
    String query, {
    String? excludeConversationId,
  }) async {
    final snap = await _conversations(
      uid,
    ).orderBy('updatedAt', descending: true).limit(100).get();
    final chats = snap.docs
        .map((doc) => Conversation.fromMap(doc.id, doc.data()))
        .where((c) => c.id != excludeConversationId)
        .toList();
    final matches = rankByTitle(chats, query, title: (c) => c.title);

    return Future.wait(
      matches.map((chat) async {
        final first = await _messages(
          uid,
          chat.id,
        ).orderBy('createdAt').limit(2).get();
        final preview = first.docs
            .map((d) => ChatMessage.fromMap(d.id, d.data()))
            .map(
              (m) =>
                  '${m.isUser ? 'User' : 'Nova'}: ${_short(plainText(m.text))}',
            )
            .join('\n');
        return ChatSearchHit(
          title: chat.title,
          updatedAt: chat.updatedAt,
          preview: preview,
        );
      }),
    );
  }

  static String _short(String text) {
    final oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return oneLine.length <= 300 ? oneLine : '${oneLine.substring(0, 300)}…';
  }

  // ---------- Messages ----------

  /// The newest [AppConstants.maxLoadedMessages] messages of a chat,
  /// oldest first (the order a chat is read in). Updates live.
  Stream<List<ChatMessage>> watchMessages(String uid, String conversationId) {
    return _messages(uid, conversationId)
        // Newest first, so the limit keeps the most recent messages...
        .orderBy('createdAt', descending: true)
        .limit(AppConstants.maxLoadedMessages)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => ChatMessage.fromMap(doc.id, doc.data()))
              .toList()
              // ...then flip them so the chat reads top to bottom.
              .reversed
              .toList(),
        );
  }

  /// Saves one message and bumps the chat's updatedAt, in a single batch:
  /// either both writes happen or neither does.
  ///
  /// For an attachment, only its kind and name are saved, never the file.
  /// Returns the new message's id.
  Future<String> addMessage({
    required String uid,
    required String conversationId,
    required MessageRole role,
    required String text,
    AttachmentKind? attachmentKind,
    String? attachmentName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const InvalidMessageException('Message is empty.');
    }
    if (role == MessageRole.user &&
        trimmed.length > AppConstants.maxUserMessageLength) {
      throw const InvalidMessageException('Message is too long.');
    }
    // Very long answers are cut to fit the rules instead of failing to save.
    final toSave =
        role == MessageRole.model &&
            trimmed.length > AppConstants.maxModelMessageLength
        ? trimmed.substring(0, AppConstants.maxModelMessageLength)
        : trimmed;

    final doc = _messages(uid, conversationId).doc();
    final batch = _db.batch();
    batch.set(
      doc,
      ChatMessage.newMessageData(
        role: role,
        text: toSave,
        attachmentKind: role == MessageRole.user ? attachmentKind : null,
        attachmentName: role == MessageRole.user ? attachmentName : null,
      ),
    );
    batch.update(_conversations(uid).doc(conversationId), {
      'updatedAt': FieldValue.serverTimestamp(),
      // The chat now has an answer, so it shows in the chat list.
      if (role == MessageRole.model) 'answered': true,
    });
    await batch.commit();
    return doc.id;
  }
}

/// Makes a short, single-line title (used for chat titles).
String cleanTitle(String raw) {
  final oneLine = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (oneLine.isEmpty) return 'New chat';
  if (oneLine.length <= AppConstants.maxTitleLength) return oneLine;
  return '${oneLine.substring(0, AppConstants.maxTitleLength - 1).trimRight()}…';
}
