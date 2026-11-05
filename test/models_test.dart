import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/constants.dart';
import 'package:nova_chat/models/chat_message.dart';
import 'package:nova_chat/models/conversation.dart';
import 'package:nova_chat/services/chat_repository.dart';

void main() {
  group('ChatMessage', () {
    test('reads a normal Firestore document', () {
      final time = DateTime.utc(2026, 11, 2, 10);
      final m = ChatMessage.fromMap('m1', {
        'role': 'model',
        'text': 'Hi!',
        'createdAt': Timestamp.fromDate(time),
      });
      expect(m.id, 'm1');
      expect(m.role, MessageRole.model);
      expect(m.text, 'Hi!');
      // Same moment in time (Firestore gives it back in local time).
      expect(m.createdAt!.isAtSameMomentAs(time), isTrue);
    });

    test('survives missing or wrong-typed fields', () {
      final m = ChatMessage.fromMap('m2', {'role': 42, 'text': null});
      expect(m.role, MessageRole.user);
      expect(m.text, '');
      expect(m.createdAt, isNull); // e.g. server time not confirmed yet
    });

    test('new message data uses a server timestamp and only allowed keys', () {
      final data = ChatMessage.newMessageData(
        role: MessageRole.user,
        text: 'Hello',
      );
      // Must match hasOnly([...]) in firestore.rules.
      expect(data.keys.toSet(), {'role', 'text', 'createdAt'});
      expect(data['role'], 'user');
      expect(data['createdAt'], isA<FieldValue>());
    });
  });

  group('Conversation', () {
    test('falls back to a default title', () {
      final c = Conversation.fromMap('c1', {});
      expect(c.title, 'New chat');
      expect(c.projectId, isNull);
    });
  });

  group('cleanTitle', () {
    test('collapses whitespace and newlines', () {
      expect(cleanTitle('  Hello\n\n  world  '), 'Hello world');
    });

    test('empty becomes "New chat"', () {
      expect(cleanTitle('   '), 'New chat');
    });

    test('long titles are cut to the limit', () {
      final title = cleanTitle('a' * 500);
      expect(title.length, AppConstants.maxTitleLength);
      expect(title.endsWith('…'), isTrue);
    });
  });
}
