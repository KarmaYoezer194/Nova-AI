import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/saved_item.dart';
import 'chat_repository.dart';

/// Reads and writes the user's saved answers: users/{uid}/saved/{id}.
///
/// Like the other repositories, every path starts with users/{uid}, and
/// firestore.rules checks ownership and sizes on the server.
class SavedRepository {
  SavedRepository({FirebaseFirestore? firestore}) : _dbOverride = firestore;

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _saved(String uid) =>
      _db.collection('users').doc(uid).collection('saved');

  /// All saved answers, newest first (up to 200). Updates live.
  Stream<List<SavedItem>> watchSaved(String uid) => _saved(uid)
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => SavedItem.fromMap(d.data())).toList(),
      );

  /// Ids of the saved answers in one chat, so the chat can fill their
  /// bookmark icons. Updates live.
  Stream<Set<String>> watchSavedIn(String uid, String conversationId) =>
      _saved(uid)
          .where('conversationId', isEqualTo: conversationId)
          .snapshots()
          .map(
            (snap) => {
              for (final d in snap.docs) SavedItem.fromMap(d.data()).messageId,
            },
          );

  Future<void> save({
    required String uid,
    required String conversationId,
    required String messageId,
    required String chatTitle,
    required String answer,
  }) => _saved(uid).doc(savedId(conversationId, messageId)).set({
    'conversationId': conversationId,
    'messageId': messageId,
    'title': cleanTitle(chatTitle),
    'preview': savedPreview(answer),
    'createdAt': FieldValue.serverTimestamp(),
  });

  Future<void> remove(String uid, String conversationId, String messageId) =>
      _saved(uid).doc(savedId(conversationId, messageId)).delete();
}
