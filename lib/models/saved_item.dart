import 'package:cloud_firestore/cloud_firestore.dart';

import '../app/constants.dart';
import 'artifact.dart';

/// One answer the user saved (bookmarked).
///
/// Firestore path: users/{uid}/saved/{conversationId}_{messageId}
/// Only a short preview is kept, not the whole answer; tapping the item
/// opens the chat at the real message.
class SavedItem {
  const SavedItem({
    required this.conversationId,
    required this.messageId,
    required this.title,
    required this.preview,
    this.createdAt,
  });

  final String conversationId;
  final String messageId;

  /// The chat's title when the answer was saved.
  final String title;
  final String preview;
  final DateTime? createdAt;

  String get id => savedId(conversationId, messageId);

  factory SavedItem.fromMap(Map<String, dynamic> data) {
    String str(String key) => data[key] is String ? data[key] as String : '';
    final created = data['createdAt'];
    return SavedItem(
      conversationId: str('conversationId'),
      messageId: str('messageId'),
      title: str('title').isEmpty ? 'Chat' : str('title'),
      preview: str('preview'),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

/// The document id of a saved answer. One id per answer, so the same
/// answer can't be saved twice (the rules check this too).
String savedId(String conversationId, String messageId) =>
    '${conversationId}_$messageId';

/// A one-line preview of an answer, at most
/// [AppConstants.maxSavedPreviewLength] characters (artifact tags removed).
String savedPreview(String answer) {
  final oneLine = plainText(answer).replaceAll(RegExp(r'\s+'), ' ').trim();
  const max = AppConstants.maxSavedPreviewLength;
  if (oneLine.length <= max) return oneLine;
  return '${oneLine.substring(0, max - 1).trimRight()}…';
}
