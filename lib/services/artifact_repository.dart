import 'package:cloud_firestore/cloud_firestore.dart';

import '../app/constants.dart';
import '../models/artifact.dart';

/// Saves and reads artifact versions:
/// users/{uid}/conversations/{cid}/artifacts/{id}
///
/// Only the APP saves versions, after Nova's answer is complete. Nova itself
/// can't write anything (security rule 5).
class ArtifactRepository {
  ArtifactRepository({FirebaseFirestore? firestore}) : _dbOverride = firestore;

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  /// Most artifacts saved from one answer.
  static const int maxPerMessage = 5;

  /// Most versions kept per artifact in a chat.
  static const int maxVersions = 50;

  CollectionReference<Map<String, dynamic>> _artifacts(
    String uid,
    String conversationId,
  ) => _db
      .collection('users')
      .doc(uid)
      .collection('conversations')
      .doc(conversationId)
      .collection('artifacts');

  /// All versions of one artifact in a chat, oldest first. Updates live.
  Stream<List<ArtifactVersion>> watchVersions(
    String uid,
    String conversationId,
    String key,
  ) {
    // Sorted here rather than with orderBy, so Firestore needs no extra index.
    return _artifacts(uid, conversationId)
        .where('key', isEqualTo: key)
        .limit(maxVersions)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => ArtifactVersion.fromMap(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) => a.version.compareTo(b.version)),
        );
  }

  /// Saves the artifacts of a finished answer as new versions.
  /// Unchanged content (same as the latest version) is not saved again.
  Future<void> saveVersions({
    required String uid,
    required String conversationId,
    required String messageId,
    required List<ArtifactBlock> blocks,
  }) async {
    final batch = _db.batch();
    var writes = 0;
    final nextVersion = <String, int>{};

    for (final block in blocks.take(maxPerMessage)) {
      if (!block.isComplete || block.content.trim().isEmpty) continue;
      if (block.content.length > AppConstants.maxModelMessageLength) continue;

      final key = block.key;
      if (!nextVersion.containsKey(key)) {
        final existing = await _artifacts(
          uid,
          conversationId,
        ).where('key', isEqualTo: key).limit(maxVersions).get();
        final versions =
            existing.docs
                .map((d) => ArtifactVersion.fromMap(d.id, d.data()))
                .toList()
              ..sort((a, b) => a.version.compareTo(b.version));
        if (versions.length >= maxVersions) continue;
        if (versions.isNotEmpty && versions.last.content == block.content) {
          continue;
        }
        nextVersion[key] = versions.isEmpty ? 1 : versions.last.version + 1;
      }
      final version = nextVersion[key]!;
      nextVersion[key] = version + 1;

      batch.set(_artifacts(uid, conversationId).doc(), {
        'key': key,
        'title': block.title,
        'kind': block.kind.name,
        'language': ?block.language, // Only added when set.
        'content': block.content,
        'version': version,
        'messageId': messageId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      writes++;
    }
    if (writes > 0) await batch.commit();
  }
}
