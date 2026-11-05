import 'package:cloud_firestore/cloud_firestore.dart';

/// One chat in the sidebar.
///
/// Firestore path: users/{uid}/conversations/{id}
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    this.projectId,
    this.answered,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;

  /// The project this chat belongs to (Phase 9). Null for normal chats.
  final String? projectId;

  /// False until Nova's first answer is saved. Null for chats made before
  /// this was added (they are always shown).
  final bool? answered;

  /// Chats without an answer yet are hidden from the chat list.
  bool get isVisible => answered != false;

  final DateTime? createdAt;

  /// Bumped every time a message is added, so the newest chats sort first.
  final DateTime? updatedAt;

  factory Conversation.fromMap(String id, Map<String, dynamic> data) {
    DateTime? toDate(Object? value) =>
        value is Timestamp ? value.toDate() : null;

    return Conversation(
      id: id,
      title: data['title'] is String ? data['title'] as String : 'New chat',
      projectId: data['projectId'] is String
          ? data['projectId'] as String
          : null,
      answered: data['answered'] is bool ? data['answered'] as bool : null,
      createdAt: toDate(data['createdAt']),
      updatedAt: toDate(data['updatedAt']),
    );
  }
}
