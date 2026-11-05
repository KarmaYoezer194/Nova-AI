import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../app/constants.dart';
import '../models/memory.dart';

/// Thrown with a message that is safe to show to users.
class MemoryException implements Exception {
  const MemoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads and writes what the user shares with Nova:
/// - custom instructions: the `customInstructions` field of users/{uid}
/// - memories: users/{uid}/memories/{id}
///
/// Like [ChatRepository], every path starts with users/{uid}, and
/// firestore.rules checks ownership and sizes on the server.
class MemoryRepository {
  MemoryRepository({FirebaseFirestore? firestore}) : _dbOverride = firestore;

  final FirebaseFirestore? _dbOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _memories(String uid) =>
      _user(uid).collection('memories');

  // ---------- Custom instructions ----------

  Future<String> loadCustomInstructions(String uid) async {
    final snap = await _user(uid).get();
    final value = snap.data()?['customInstructions'];
    return value is String ? value : '';
  }

  /// Saves the instructions. An empty text removes them.
  Future<void> saveCustomInstructions(String uid, String text) async {
    final trimmed = text.trim();
    if (trimmed.length > AppConstants.maxCustomInstructionsLength) {
      throw const MemoryException('That text is too long.');
    }
    final doc = _user(uid);
    final snap = await doc.get();
    if (!snap.exists) {
      // First save: create the user document. The rules require createdAt
      // to be the server's time.
      await doc.set({
        'createdAt': FieldValue.serverTimestamp(),
        if (trimmed.isNotEmpty) 'customInstructions': trimmed,
      });
    } else {
      await doc.update({
        'customInstructions': trimmed.isEmpty ? FieldValue.delete() : trimmed,
      });
    }
  }

  // ---------- Memories ----------

  Query<Map<String, dynamic>> _newestMemories(String uid) => _memories(
    uid,
  ).orderBy('createdAt', descending: true).limit(AppConstants.maxMemories);

  /// The user's memories, newest first. Updates live.
  Stream<List<Memory>> watchMemories(String uid) {
    return _newestMemories(uid).snapshots().map(
      (snap) =>
          snap.docs.map((doc) => Memory.fromMap(doc.id, doc.data())).toList(),
    );
  }

  /// Saves a new memory. Throws [MemoryException] if it is empty, too long,
  /// or the user already has the maximum number.
  Future<void> addMemory(String uid, String text) async {
    final clean = cleanMemoryText(text);
    if (clean.isEmpty) throw const MemoryException('Please type something.');
    if (clean.length > AppConstants.maxMemoryLength) {
      throw const MemoryException('That memory is too long.');
    }
    final existing = await _newestMemories(uid).get();
    if (existing.docs.length >= AppConstants.maxMemories) {
      throw const MemoryException(
        'You have ${AppConstants.maxMemories} memories, the maximum. '
        'Delete one in Settings first.',
      );
    }
    await _memories(
      uid,
    ).add({'text': clean, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteMemory(String uid, String memoryId) =>
      _memories(uid).doc(memoryId).delete();

  /// Deletes every memory (in batches, since there is no "delete all").
  Future<void> deleteAllMemories(String uid) async {
    while (true) {
      final page = await _memories(uid).limit(200).get();
      if (page.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // ---------- For the AI ----------

  // Speed: instead of asking the server before EVERY answer (two round
  // trips, which made answers start later), we listen once and keep the
  // latest copy here. Firestore pushes changes to us, including edits made
  // in Settings, so the copy is always current.
  String? _watchedUid;
  String? _instructions;
  List<String>? _memoryTexts;
  StreamSubscription<Object?>? _userSub;
  StreamSubscription<Object?>? _memoriesSub;

  /// Called right after sign-in, so even the first answer doesn't wait.
  void preload(String uid) => _watch(uid);

  /// Called on sign-out, so we stop listening to that user's data.
  void stopWatching() => _stopWatching();

  void _watch(String uid) {
    if (_watchedUid == uid) return;
    _stopWatching();
    _watchedUid = uid;
    void onError(Object error) {
      if (kDebugMode) debugPrint('Personalization listener error: $error');
      _stopWatching(); // Next answer falls back to a direct read.
    }

    _userSub = _user(uid).snapshots().listen((snap) {
      final value = snap.data()?['customInstructions'];
      _instructions = value is String ? value : '';
    }, onError: onError);
    _memoriesSub = _newestMemories(uid).snapshots().listen((snap) {
      _memoryTexts = _memoryTextsFrom(snap);
    }, onError: onError);
  }

  void _stopWatching() {
    _userSub?.cancel();
    _memoriesSub?.cancel();
    _userSub = _memoriesSub = null;
    _watchedUid = _instructions = _memoryTexts = null;
  }

  static List<String> _memoryTextsFrom(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) => snap.docs
      .map((doc) => Memory.fromMap(doc.id, doc.data()).text)
      .where((t) => t.trim().isNotEmpty)
      .toList()
      .reversed // Oldest first reads more naturally in the prompt.
      .toList();

  /// Everything to add to the system prompt. Instant once the live copy has
  /// arrived; the very first time, it reads from the server.
  Future<Personalization> loadPersonalization(String uid) async {
    _watch(uid);
    final instructions = _instructions;
    final memories = _memoryTexts;
    if (instructions != null && memories != null) {
      return Personalization(
        customInstructions: instructions,
        memories: memories,
      );
    }
    final results = await Future.wait([
      loadCustomInstructions(uid),
      _newestMemories(uid).get(),
    ]);
    return Personalization(
      customInstructions: results[0] as String,
      memories: _memoryTextsFrom(
        results[1] as QuerySnapshot<Map<String, dynamic>>,
      ),
    );
  }
}
