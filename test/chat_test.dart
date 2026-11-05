import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/constants.dart';
import 'package:nova_chat/app/theme.dart';
import 'package:nova_chat/models/chat_message.dart';
import 'package:nova_chat/models/conversation.dart';
import 'package:nova_chat/screens/chat_screen.dart';
import 'package:nova_chat/screens/chat_shell.dart';
import 'package:nova_chat/widgets/chat_input.dart';
import 'package:nova_chat/widgets/empty_chat.dart';
import 'package:nova_chat/widgets/markdown_message.dart';
import 'package:nova_chat/widgets/sidebar.dart';

import 'fakes.dart';
import 'package:nova_chat/app/nova_icons.dart';

void main() {
  group('ChatScreen', () {
    Future<void> pumpNewChat(
      WidgetTester tester,
      FakeChatRepository repo, {
      FakeAiService? ai,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ChatScreen(
              uid: 'user-a',
              services: fakeServices(chat: repo, ai: ai),
              initialConversationId: null,
              onConversationCreated: (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('new chat shows greeting, 3 example prompts and disclaimer', (
      tester,
    ) async {
      await pumpNewChat(tester, FakeChatRepository());

      expect(
        find.textContaining(RegExp(r'^Good (morning|afternoon|evening)')),
        findsOneWidget,
      );
      expect(find.text('What are we working on today?'), findsOneWidget);
      for (final prompt in AppConstants.examplePrompts) {
        expect(find.text(prompt), findsOneWidget);
      }
      for (final title in ['Explain a topic', 'Plan my week', 'Get ideas']) {
        expect(find.text(title), findsOneWidget);
      }
      // The big composer is part of the greeting; there's only one.
      expect(find.byType(ChatInput), findsOneWidget);
      expect(find.text(AppConstants.disclaimer), findsOneWidget);
    });

    test('streaming cursor goes after the text, never inside open code', () {
      final m = cursorMarker;
      expect(withCursor('Hello'), endsWith(m));
      expect(withCursor('```dart\nvoid main'), isNot(contains(m)));
      // A marker written by the model itself is removed.
      expect(m.allMatches(withCursor('a${m}b')).length, 1);
      expect(withCursor('a${m}b'), startsWith('ab'));
    });

    test('greeting follows the time of day', () {
      expect(greetingFor(DateTime(2026, 11, 5, 8)), 'Good morning');
      expect(greetingFor(DateTime(2026, 11, 5, 14)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 11, 5, 21)), 'Good evening');
    });

    test('greeting name: display name first, else the email', () {
      expect(greetingNameFrom('John Smith', 'x@y.com'), 'John');
      expect(greetingNameFrom(null, 'john.smith42@gmail.com'), 'John');
      expect(greetingNameFrom('', null), isNull);
    });

    testWidgets('sending creates a titled chat, saves the question, '
        'then saves the full answer once', (tester) async {
      final repo = FakeChatRepository();
      await pumpNewChat(tester, repo, ai: FakeAiService(pieces: ['Hel', 'lo']));

      final prompt = AppConstants.examplePrompts.first;
      await tester.tap(find.text(prompt));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(repo.createdTitle, prompt);
      expect(repo.saved, [
        (MessageRole.user, prompt),
        (MessageRole.model, 'Hello'), // Joined pieces, saved once.
      ]);
    });

    testWidgets('a sent message appears only once while the server confirms', (
      tester,
    ) async {
      final repo = FakeChatRepository()
        ..emitOnSave = true
        ..userSaveGate = Completer<void>();
      final answer = StreamController<String>();
      await pumpNewChat(tester, repo, ai: FakeAiService(controller: answer));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump(); // Lets the Send button become enabled.
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump(const Duration(milliseconds: 10));

      // Really sent: the user message was saved and the box is empty again.
      expect(repo.saved.first, (MessageRole.user, 'hello'));
      // Firestore's local copy is showing; the server hasn't confirmed yet.
      expect(find.text('hello'), findsOneWidget);

      repo.userSaveGate!.complete();
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('hello'), findsOneWidget);

      await tester.tap(find.byTooltip('Stop answering'));
      await tester.pump(const Duration(milliseconds: 10));
      unawaited(answer.close());
    });

    testWidgets('Stop ends the answer early and saves what arrived', (
      tester,
    ) async {
      final repo = FakeChatRepository();
      final answer = StreamController<String>();
      await pumpNewChat(tester, repo, ai: FakeAiService(controller: answer));

      await tester.tap(find.text(AppConstants.examplePrompts.first));
      await tester.pump(const Duration(milliseconds: 10));
      answer.add('Partial answer');
      await tester.pump(const Duration(milliseconds: 10));

      // While streaming, Send has become Stop.
      expect(find.byTooltip('Stop answering'), findsOneWidget);
      await tester.tap(find.byTooltip('Stop answering'));
      await tester.pump(const Duration(milliseconds: 10));

      expect(repo.saved.last, (MessageRole.model, 'Partial answer'));
      expect(find.byTooltip('Send message'), findsOneWidget);
      // Not awaited: after Stop nobody listens, so "closed" is never confirmed.
      unawaited(answer.close());
    });
  });

  group('ChatInput', () {
    testWidgets('Send is disabled when empty and while busy', (tester) async {
      Widget input({required bool busy}) => MaterialApp(
        home: Scaffold(
          body: ChatInput(onSend: (_, _) {}, isBusy: busy),
        ),
      );

      await tester.pumpWidget(input(busy: false));
      IconButton send() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, NovaIcons.send),
      );
      expect(send().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.pump();
      expect(send().onPressed, isNotNull);

      await tester.pumpWidget(input(busy: true));
      expect(find.widgetWithIcon(IconButton, NovaIcons.send), findsNothing);
      expect(find.byTooltip('Stop answering'), findsOneWidget);
    });
  });

  group('ChatShell layout', () {
    final repo = FakeChatRepository(
      chats: const [Conversation(id: 'c1', title: 'Trip to Chiang Mai')],
    );

    Future<void> pumpShell(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ChatShell(
            services: fakeServices(chat: repo),
            uid: 'user-a',
            email: 'a@example.com',
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('wide screen: sidebar always visible', (tester) async {
      await pumpShell(tester, const Size(1200, 800));

      expect(find.widgetWithText(FilledButton, 'New chat'), findsOneWidget);
      expect(find.text('Trip to Chiang Mai'), findsOneWidget);
    });

    testWidgets('phone: sidebar hidden until the menu is opened', (
      tester,
    ) async {
      await pumpShell(tester, const Size(400, 800));

      expect(find.text('Trip to Chiang Mai'), findsNothing);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.text('Trip to Chiang Mai'), findsOneWidget);
    });
  });
}
