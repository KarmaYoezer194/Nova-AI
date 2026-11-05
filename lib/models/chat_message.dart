import 'package:cloud_firestore/cloud_firestore.dart';

import 'attachment.dart';

/// Who wrote a message. Stored in Firestore as "user" or "model".
enum MessageRole {
  user,
  model;

  static MessageRole fromName(Object? value) =>
      value == 'model' ? MessageRole.model : MessageRole.user;
}

/// One message in a conversation.
///
/// Firestore path: users/{uid}/conversations/{conversationId}/messages/{id}
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.createdAt,
    this.attachmentKind,
    this.attachmentName,
  });

  final String id;
  final MessageRole role;
  final String text;

  /// Set by the server. Null for a moment right after sending, until the
  /// server has confirmed the write.
  final DateTime? createdAt;

  /// A note that a file was attached. The file itself is never stored.
  final AttachmentKind? attachmentKind;
  final String? attachmentName;

  bool get isUser => role == MessageRole.user;
  bool get hasAttachment => attachmentKind != null;

  /// Builds a message from a Firestore document's data.
  /// Defensive: a missing or wrong-typed field never crashes the app.
  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    final name = data['attachmentName'];
    return ChatMessage(
      id: id,
      role: MessageRole.fromName(data['role']),
      text: data['text'] is String ? data['text'] as String : '',
      createdAt: created is Timestamp ? created.toDate() : null,
      attachmentKind: AttachmentKind.fromName(data['attachmentKind']),
      attachmentName: name is String ? name : null,
    );
  }

  /// The data we write for a new message. The server fills in the time,
  /// so a wrong clock on the user's device doesn't matter.
  static Map<String, dynamic> newMessageData({
    required MessageRole role,
    required String text,
    AttachmentKind? attachmentKind,
    String? attachmentName,
  }) {
    return {
      'role': role.name,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      if (attachmentKind != null) 'attachmentKind': attachmentKind.name,
      if (attachmentKind != null && attachmentName != null)
        'attachmentName': attachmentName,
    };
  }
}
