import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/constants.dart';
import 'package:nova_chat/models/attachment.dart';
import 'package:nova_chat/models/chat_message.dart';
import 'package:nova_chat/services/ai_service.dart';
import 'package:nova_chat/widgets/message_bubble.dart';

Uint8List bytesOf(List<int> start, [int padTo = 64]) =>
    Uint8List.fromList([...start, ...List.filled(padTo, 0)]);

final png = bytesOf([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
final jpeg = bytesOf([0xFF, 0xD8, 0xFF, 0xE0]);
final webp = bytesOf([
  ...ascii.encode('RIFF'),
  0,
  0,
  0,
  0,
  ...ascii.encode('WEBP'),
]);
final pdf = bytesOf(ascii.encode('%PDF-1.7'));

void main() {
  group('file type is decided by content, not by name', () {
    test('recognises PNG, JPEG, WebP and PDF', () {
      expect(detectMimeType(png), 'image/png');
      expect(detectMimeType(jpeg), 'image/jpeg');
      expect(detectMimeType(webp), 'image/webp');
      expect(detectMimeType(pdf), 'application/pdf');
    });

    test('a text file renamed to .jpg is rejected', () {
      final fake = Uint8List.fromList(utf8.encode('just some text pretending'));
      expect(
        () => Attachment.fromPickedFile(name: 'notes.jpg', bytes: fake),
        throwsA(isA<AttachmentException>()),
      );
    });

    test('a real PDF named .jpg is treated as a PDF', () {
      final a = Attachment.fromPickedFile(name: 'trick.jpg', bytes: pdf);
      expect(a.kind, AttachmentKind.pdf);
      expect(a.mimeType, 'application/pdf');
    });
  });

  group('limits', () {
    test('empty and too-big files are rejected', () {
      expect(
        () => Attachment.fromPickedFile(name: 'a.png', bytes: Uint8List(0)),
        throwsA(isA<AttachmentException>()),
      );
      final huge = Uint8List(AppConstants.maxAttachmentBytes + 1)
        ..setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(
        () => Attachment.fromPickedFile(name: 'big.png', bytes: huge),
        throwsA(isA<AttachmentException>()),
      );
    });

    test('file names are cleaned (no folders, one line, max length)', () {
      expect(cleanFileName(r'C:\Users\me\Desktop\notes.png'), 'notes.png');
      expect(cleanFileName('a\nb.png'), 'a b.png');
      expect(
        cleanFileName('x' * 500).length,
        AppConstants.maxAttachmentNameLength,
      );
    });
  });

  group('what is sent to the AI', () {
    test('the file goes with the new message, before its text', () {
      final a = Attachment.fromPickedFile(name: 'notes.png', bytes: png);
      final contents = buildContents(
        history: const [],
        userText: 'Explain my notes',
        attachment: a,
      );
      final parts = contents.last.parts;
      expect(contents.last.role, 'user');
      expect(parts.first, isA<InlineDataPart>());
      expect((parts.first as InlineDataPart).mimeType, 'image/png');
      expect((parts.last as TextPart).text, 'Explain my notes');
    });

    test('older files are described as no longer available', () {
      final contents = buildContents(
        history: const [
          ChatMessage(
            id: '1',
            role: MessageRole.user,
            text: 'What is this?',
            attachmentKind: AttachmentKind.image,
            attachmentName: 'notes.png',
          ),
          ChatMessage(id: '2', role: MessageRole.model, text: 'Your notes.'),
        ],
        userText: 'And the second line?',
      );
      final first = (contents.first.parts.single as TextPart).text;
      expect(first, contains('no longer available'));
      expect(first, contains('notes.png'));
      // No file data is sent for old messages.
      expect(
        contents.expand((c) => c.parts).whereType<InlineDataPart>(),
        isEmpty,
      );
    });
  });

  group('saved note', () {
    test('only kind and name are saved, never the file', () {
      final data = ChatMessage.newMessageData(
        role: MessageRole.user,
        text: 'Explain',
        attachmentKind: AttachmentKind.pdf,
        attachmentName: 'week3.pdf',
      );
      // Must match hasOnly([...]) in firestore.rules.
      expect(data.keys.toSet(), {
        'role',
        'text',
        'createdAt',
        'attachmentKind',
        'attachmentName',
      });
      expect(data['attachmentKind'], 'pdf');
    });

    testWidgets('an old message shows a "PDF attached" note', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              role: MessageRole.user,
              text: 'Summarise this',
              attachmentKind: AttachmentKind.pdf,
              attachmentName: 'week3.pdf',
            ),
          ),
        ),
      );
      expect(find.text('PDF attached: week3.pdf'), findsOneWidget);
    });
  });
}
