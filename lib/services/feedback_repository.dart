import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/saved_item.dart';

/// A thumbs up or down on one of Nova's answers.
enum Rating { up, down }

/// Reads and writes ratings: users/{uid}/feedback/{conversationId}_{messageId}.
///
/// Only the ids and the rating are stored, never the answer. Owner-only,
/// checked by firestore.rules.
class FeedbackRepository {
  FeedbackRepository({FirebaseFirestore? firestore}) : _dbOverride = firestore;

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _feedback(String uid) =>
      _db.collection('users').doc(uid).collection('feedback');

  /// The ratings in one chat, by message id. Updates live.
  Stream<Map<String, Rating>> watchIn(String uid, String conversationId) =>
      _feedback(uid)
          .where('conversationId', isEqualTo: conversationId)
          .snapshots()
          .map(
            (snap) => {
              for (final d in snap.docs)
                if (d.data()['messageId'] is String)
                  d.data()['messageId'] as String: d.data()['rating'] == 'up'
                      ? Rating.up
                      : Rating.down,
            },
          );

  /// Sets the rating of one answer. [replacing] is true when the answer
  /// already has a rating (it is changed, keeping its first time).
  Future<void> rate({
    required String uid,
    required String conversationId,
    required String messageId,
    required Rating rating,
    bool replacing = false,
  }) {
    final doc = _feedback(uid).doc(savedId(conversationId, messageId));
    if (replacing) return doc.update({'rating': rating.name});
    return doc.set({
      'conversationId': conversationId,
      'messageId': messageId,
      'rating': rating.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String uid, String conversationId, String messageId) =>
      _feedback(uid).doc(savedId(conversationId, messageId)).delete();
}
