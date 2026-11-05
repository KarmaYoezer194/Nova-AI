// UI round 2: Regenerate, Edit, thumbs up / down, and the top bar menu.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/theme.dart';
import 'package:nova_chat/models/chat_message.dart';
import 'package:nova_chat/models/conversation.dart';
import 'package:nova_chat/models/project.dart';
import 'package:nova_chat/screens/chat_screen.dart';
import 'package:nova_chat/screens/chat_shell.dart';
import 'package:nova_chat/services/feedback_repository.dart';

import 'fakes.dart';

const _chat = [
  ChatMessage(id: 'm1', role: MessageRole.user, text: 'First question'),
  ChatMessage(id: 'm2', role: MessageRole.model, text: 'First answer'),
  ChatMessage(id: 'm3', role: MessageRole.user, text: 'Second question'),
  ChatMessage(id: 'm4', role: MessageRole.model, text: 'Second answer'),
];

void main() {
  late FakeChatRepository chat;
  late FakeAiService ai;
  late FakeFeedbackRepository feedback;

  Future<void> pumpChat(WidgetTester tester) async {
    chat = FakeChatRepository();
    ai = FakeAiService(pieces: ['New answer']);
    feedback = FakeFeedbackRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ChatScreen(
            uid: 'user-a',
            services: fakeServices(chat: chat, ai: ai, feedback: feedback),
            initialConversationId: 'c1',
            onConversationCreated: (_) {},
          ),
        ),
      ),
    );
    chat.messages.add(_chat);
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('Regenerate is only under the latest answer, and asks again', (
    tester,
  ) async {
    await pumpChat(tester);
    expect(find.byTooltip('Regenerate answer'), findsOneWidget);

    await tester.tap(find.byTooltip('Regenerate answer'));
    await settle(tester);

    expect(chat.deletedMessages.single.$1, 'c1');
    expect(chat.deletedMessages.single.$2, ['m4']);
    // Same question; history is everything before it.
    expect(ai.lastHistory?.map((m) => m.id), ['m1', 'm2']);
    expect(chat.saved, [(MessageRole.model, 'New answer')]);
  });

  testWidgets('Edit is only on my latest message; sending replaces it', (
    tester,
  ) async {
    await pumpChat(tester);
    expect(find.byTooltip('Edit message'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit message'));
    await tester.pump();
    expect(find.text('Editing message'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Second question'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Better question');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await settle(tester);

    expect(chat.deletedMessages.single.$1, 'c1');
    expect(chat.deletedMessages.single.$2, ['m3', 'm4']);
    expect(ai.lastHistory?.map((m) => m.id), ['m1', 'm2']);
    expect(chat.saved, [
      (MessageRole.user, 'Better question'),
      (MessageRole.model, 'New answer'),
    ]);
  });

  testWidgets('Cancel stops editing and clears the box', (tester) async {
    await pumpChat(tester);
    await tester.tap(find.byTooltip('Edit message'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Editing message'), findsNothing);
    expect(find.widgetWithText(TextField, 'Second question'), findsNothing);
  });

  testWidgets('thumbs up / down under every answer; tap again removes', (
    tester,
  ) async {
    await pumpChat(tester);
    expect(find.byTooltip('Good response'), findsNWidgets(2));
    expect(find.byTooltip('Bad response'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Good response').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Bad response').first); // Switch.
    await tester.pump();
    await tester.tap(find.byTooltip('Remove bad response'));
    await tester.pump();

    // All three taps are on the same answer.
    final id = feedback.changes.first.$1;
    expect(feedback.changes, [
      (id, Rating.up, false),
      (id, Rating.down, true),
      (id, null, false),
    ]);
  });

  group('top bar', () {
    const project = Project(id: 'p1', name: 'Networking exam');

    Future<void> pumpShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      chat = FakeChatRepository(
        chats: const [Conversation(id: 'c1', title: 'Trip plans')],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ChatShell(
            services: fakeServices(
              chat: chat,
              projects: FakeProjectRepository(projects: const [project]),
            ),
            uid: 'user-a',
            email: 'a@example.com',
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Trip plans'));
      await tester.pump();
    }

    // The top bar's menu is the last "Chat options" button (the sidebar
    // row has one too).
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Chat options').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('rename the open chat', (tester) async {
      await pumpShell(tester);
      await openMenu(tester);
      await tester.tap(find.text('Rename'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(
        find.widgetWithText(TextField, 'Trip plans'),
        'Chiang Mai trip',
      );
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(chat.renames, [('c1', 'Chiang Mai trip')]);
    });

    testWidgets('move the open chat into a project', (tester) async {
      await pumpShell(tester);
      await openMenu(tester);
      await tester.tap(find.text('Move to project'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Networking exam').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(chat.moves, [('c1', 'p1')]);
    });

    testWidgets('delete asks first', (tester) async {
      await pumpShell(tester);
      await openMenu(tester);
      await tester.tap(find.text('Delete chat'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Delete chat?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Delete chat?'), findsNothing);
    });
  });
}
