import 'package:cloud_firestore/cloud_firestore.dart';

import '../app/constants.dart';

/// A short fact the user asked Nova to remember across chats.
///
/// Firestore path: users/{uid}/memories/{id}
/// Only the user creates memories (by tapping "Remember" or adding one in
/// Settings). The AI can't: it only produces text (security rule 5).
class Memory {
  const Memory({required this.id, required this.text, this.createdAt});

  final String id;
  final String text;
  final DateTime? createdAt;

  factory Memory.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return Memory(
      id: id,
      text: data['text'] is String ? data['text'] as String : '',
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

/// What the user chose to share with Nova: their custom instructions,
/// memories and first name. Added to the system prompt of every chat.
class Personalization {
  const Personalization({
    this.customInstructions = '',
    this.memories = const [],
    this.firstName,
  });

  static const empty = Personalization();

  final String customInstructions;

  /// Memory texts, oldest first.
  final List<String> memories;

  /// From the display name the user set (see [firstNameFrom]); null if none.
  final String? firstName;

  bool get isEmpty =>
      customInstructions.trim().isEmpty &&
      memories.isEmpty &&
      firstName == null;

  /// The same, with the first name taken from [displayName].
  Personalization withDisplayName(String? displayName) => Personalization(
    customInstructions: customInstructions,
    memories: memories,
    firstName: firstNameFrom(displayName),
  );
}

/// The first word of a display name the user set, or null.
///
/// Never derived from the email (privacy rule): no display name means no
/// name. A display name that looks like an email is ignored too. Only
/// letters, apostrophes and hyphens are kept, so nothing else can reach the
/// prompt.
String? firstNameFrom(String? displayName) {
  final name = displayName?.trim() ?? '';
  if (name.isEmpty || name.contains('@')) return null;
  final first = name
      .split(RegExp(r'\s+'))
      .first
      .replaceAll(RegExp(r"[^\p{L}\p{M}'\-]", unicode: true), '');
  if (first.isEmpty) return null;
  return first.length <= 40 ? first : first.substring(0, 40);
}

/// Makes a memory one tidy line. Returns '' if nothing is left.
String cleanMemoryText(String raw) =>
    raw.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Shortens [text] to fit a memory, cutting at a word boundary if possible.
/// Used to pre-fill the "Remember" box from a long message.
String suggestMemoryText(String text) {
  final clean = cleanMemoryText(text);
  const max = AppConstants.maxMemoryLength;
  if (clean.length <= max) return clean;
  final cut = clean.substring(0, max);
  final lastSpace = cut.lastIndexOf(' ');
  return (lastSpace > max ~/ 2 ? cut.substring(0, lastSpace) : cut).trimRight();
}
