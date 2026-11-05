import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

/// Deletes a user's account and ALL their data (Phase 12).
///
/// Order matters:
/// 1. Confirm the password (proves it's really them, and Firebase requires
///    a recent sign-in before an account can be deleted).
/// 2. Delete every document under users/{uid}. Firestore does not delete
///    sub-collections for us, so each one is deleted explicitly.
/// 3. Delete the sign-in account. After this the app shows the sign-in page.
///
/// Uploaded files are never stored (Phase 7), so there is nothing else.
class AccountService {
  AccountService({required this.auth, FirebaseFirestore? firestore})
    : _dbOverride = firestore;

  final AuthService auth;
  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  Future<void> deleteAccountAndData(String uid, String password) async {
    await auth.confirmPassword(password);
    await deleteAllData(uid);
    await auth.deleteAccount();
  }

  /// Every document under users/{uid}: chats with their messages and
  /// artifact versions, memories, projects, saved answers, ratings, then the
  /// profile itself.
  Future<void> deleteAllData(String uid) async {
    final user = _db.collection('users').doc(uid);

    // Chats: delete each chat's sub-collections first.
    while (true) {
      final chats = await user.collection('conversations').limit(50).get();
      if (chats.docs.isEmpty) break;
      for (final chat in chats.docs) {
        await _deleteCollection(chat.reference.collection('messages'));
        await _deleteCollection(chat.reference.collection('artifacts'));
        await chat.reference.delete();
      }
    }
    await _deleteCollection(user.collection('memories'));
    await _deleteCollection(user.collection('projects'));
    await _deleteCollection(user.collection('saved'));
    await _deleteCollection(user.collection('feedback'));
    await user.delete(); // Profile and custom instructions.
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final page = await collection.limit(200).get();
      if (page.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
