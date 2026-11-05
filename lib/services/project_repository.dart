import 'package:cloud_firestore/cloud_firestore.dart';

import '../app/constants.dart';
import '../models/project.dart';

/// Thrown with a message that is safe to show to users.
class ProjectException implements Exception {
  const ProjectException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads and writes the user's projects: users/{uid}/projects/{id}.
///
/// Like the other repositories, every path starts with users/{uid}, and
/// firestore.rules checks ownership and sizes on the server.
class ProjectRepository {
  ProjectRepository({FirebaseFirestore? firestore}) : _dbOverride = firestore;

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _projects(String uid) =>
      _db.collection('users').doc(uid).collection('projects');

  CollectionReference<Map<String, dynamic>> _conversations(String uid) =>
      _db.collection('users').doc(uid).collection('conversations');

  // The latest copy of each project, kept up to date by [watchProjects]
  // (the sidebar always listens). Sending a message reads from here, so it
  // doesn't wait for the server (same idea as memories in Phase 8).
  String? _cacheUid;
  final Map<String, Project> _cache = {};

  /// The user's projects, newest first. Updates live.
  Stream<List<Project>> watchProjects(String uid) {
    return _projects(uid)
        .orderBy('createdAt', descending: true)
        .limit(AppConstants.maxProjects)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => Project.fromMap(doc.id, doc.data()))
              .toList();
          _cacheUid = uid;
          _cache
            ..clear()
            ..addEntries(list.map((p) => MapEntry(p.id, p)));
          return list;
        });
  }

  /// Forgets the cached projects (on sign-out).
  void clearCache() {
    _cacheUid = null;
    _cache.clear();
  }

  /// One project, or null if it doesn't exist (for example, it was deleted).
  Future<Project?> loadProject(String uid, String projectId) async {
    if (_cacheUid == uid && _cache.containsKey(projectId)) {
      return _cache[projectId];
    }
    final snap = await _projects(uid).doc(projectId).get();
    final data = snap.data();
    return data == null ? null : Project.fromMap(snap.id, data);
  }

  /// Creates a project and returns its id.
  Future<String> createProject(String uid, String name) async {
    final clean = _checkName(name);
    final existing = await _projects(uid).limit(AppConstants.maxProjects).get();
    if (existing.docs.length >= AppConstants.maxProjects) {
      throw const ProjectException(
        'You have ${AppConstants.maxProjects} projects, the maximum. '
        'Delete one first.',
      );
    }
    final doc = _projects(uid).doc();
    await doc.set({'name': clean, 'createdAt': FieldValue.serverTimestamp()});
    return doc.id;
  }

  /// Saves a project's name, instructions and notes. Empty texts are removed.
  Future<void> updateProject(
    String uid,
    String projectId, {
    required String name,
    required String instructions,
    required String notes,
  }) async {
    final clean = _checkName(name);
    final i = instructions.trim();
    final n = notes.trim();
    if (i.length > AppConstants.maxProjectInstructionsLength) {
      throw const ProjectException('The instructions are too long.');
    }
    if (n.length > AppConstants.maxProjectNotesLength) {
      throw const ProjectException('The notes are too long.');
    }
    await _projects(uid).doc(projectId).update({
      'name': clean,
      'instructions': i.isEmpty ? FieldValue.delete() : i,
      'notes': n.isEmpty ? FieldValue.delete() : n,
    });
  }

  /// Deletes a project. Its chats are KEPT, as normal chats: each one has
  /// its projectId removed first, so nothing is lost by accident.
  Future<void> deleteProject(String uid, String projectId) async {
    while (true) {
      // Updated chats no longer match, so each round gets the next ones.
      final page = await _conversations(
        uid,
      ).where('projectId', isEqualTo: projectId).limit(200).get();
      if (page.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in page.docs) {
        batch.update(doc.reference, {
          'projectId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(), // Required by the rules.
        });
      }
      await batch.commit();
    }
    await _projects(uid).doc(projectId).delete();
  }

  String _checkName(String name) {
    final clean = cleanProjectName(name);
    if (clean.isEmpty) throw const ProjectException('Please enter a name.');
    if (clean.length > AppConstants.maxProjectNameLength) {
      throw const ProjectException('That name is too long.');
    }
    return clean;
  }
}
