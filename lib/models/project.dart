import 'package:cloud_firestore/cloud_firestore.dart';

/// A project groups chats and gives them shared instructions and notes.
///
/// Firestore path: users/{uid}/projects/{id}
/// A chat belongs to a project through its `projectId` field.
class Project {
  const Project({
    required this.id,
    required this.name,
    this.instructions = '',
    this.notes = '',
    this.createdAt,
  });

  final String id;
  final String name;

  /// How Nova should behave in this project's chats (written by the user).
  final String instructions;

  /// Reference material for the project, like a syllabus or a brief.
  final String notes;

  final DateTime? createdAt;

  factory Project.fromMap(String id, Map<String, dynamic> data) {
    String text(String key) => data[key] is String ? data[key] as String : '';
    final created = data['createdAt'];
    return Project(
      id: id,
      name: text('name').isEmpty ? 'Untitled project' : text('name'),
      instructions: text('instructions'),
      notes: text('notes'),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

/// Makes a project name one tidy line.
String cleanProjectName(String raw) =>
    raw.replaceAll(RegExp(r'\s+'), ' ').trim();
