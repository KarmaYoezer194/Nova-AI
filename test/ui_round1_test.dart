// UI round 1: chat titles, hiding empty chats, chat search, Saved answers,
// button labels and the link hint.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/theme.dart';
import 'package:nova_chat/models/chat_message.dart';
import 'package:nova_chat/models/conversation.dart';
import 'package:nova_chat/models/saved_item.dart';
import 'package:nova_chat/screens/chat_screen.dart';
import 'package:nova_chat/screens/chat_shell.dart';
import 'package:nova_chat/services/ai_service.dart';
import 'package:nova_chat/widgets/chat_input.dart';
import 'package:nova_chat/widgets/sidebar.dart';

import 'fakes.dart';

void main() {
  group('suggested titles', () {
    test('quotes, full stops and "Title:" are removed', () {
      expect(
        cleanSuggestedTitle('"Bhutan\'s DHI economy overview."'),
        'Bhutan\'s DHI economy overview',
      );
      expect(
        cleanSuggestedTitle('Title: Trip to Chiang Mai'),
        'Trip to Chiang Mai',
      );
      expect(
        cleanSuggestedTitle('**Essay outline help**\nMore text'),
        'Essay outline help',
      );
    });

    test('empty or rambling answers are rejected', () {
      expect(cleanSuggestedTitle(null), isNull);
      expect(cleanSuggestedTitle('   '), isNull);
      expect(
        cleanSuggestedTitle('This is far too long to be a short chat title ok'),
        isNull,
      );
    });

    test('long titles are cut to 60 characters', () {
      final t = cleanSuggestedTitle('Supercalifragilisticexpialidocious ' * 2)!;
      expect(t.length, lessThanOrEqualTo(60));
    });
  });

  group('saved answers', () {
    test('preview is one line, without artifact tags, at most 300 chars', () {
      final preview = savedPreview(
        'Intro\n\n<artifact title="Plan" kind="document">'
        '${'word ' * 200}</artifact>',
      );
      expect(preview, isNot(contains('<artifact')));
      expect(preview, isNot(contains('\n')));
      expect(preview.length, lessThanOrEqualTo(300));
    });

    test('one id per answer', () {
      expect(savedId('c1', 'm1'), 'c1_m1');
    });
  });

  group('chat list', () {
    const chats = [
      Conversation(id: 'a', title: 'Bhutan\'s DHI economy overview'),
      Conversation(id: 'b', title: 'Trip to Chiang Mai', answered: true),
      Conversation(id: 'c', title: 'Unanswered', answered: false),
    ];

    test('chats without an answer are hidden; old chats are shown', () {
      expect(filterChats(chats, '').map((c) => c.id), ['a', 'b']);
    });

    test('search filters titles, ignoring case', () {
      expect(filterChats(chats, 'ECON').map((c) => c.id), ['a']);
      expect(filterChats(chats, 'unans'), isEmpty);
    });

    testWidgets('typing in the search box filters the sidebar', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ChatShell(
            services: fakeServices(chat: FakeChatRepository(chats: chats)),
            uid: 'user-a',
            email: 'a@example.com',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Unanswered'), findsNothing);
      expect(find.text('Trip to Chiang Mai'), findsOneWidget);
      // The search box opens from the Search button.
      expect(find.widgetWithText(TextField, 'Search chats'), findsNothing);
      await tester.tap(find.byTooltip('Search chats'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search chats'),
        'econ',
      );
      await tester.pump();
      expect(find.text('Trip to Chiang Mai'), findsNothing);
      expect(find.text('Bhutan\'s DHI economy overview'), findsOneWidget);
      expect(find.text('Saved answers'), findsOneWidget);
    });
  });

  group('ChatScreen', () {
    Future<void> pump(
      WidgetTester tester,
      AppServicesArgs args, {
      String? conversationId,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ChatScreen(
              uid: 'user-a',
              services: fakeServices(
                chat: args.chat,
                ai: args.ai,
                saved: args.saved,
              ),
              initialConversationId: conversationId,
              chatTitle: 'My chat',
              onConversationCreated: (_) {},
            ),
          ),
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
    }

    testWidgets('after the first answer, the chat gets Nova\'s title', (
      tester,
    ) async {
      final args = AppServicesArgs(
        ai: FakeAiService(pieces: ['Answer'])..title = 'DHI economy',
      );
      await pump(tester, args);
      await tester.enterText(find.byType(TextField), 'Tell me about DHI');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await settle(tester);

      expect(args.ai.titleRequests, [('Tell me about DHI', 'Answer')]);
      expect(args.chat.renames, [('new-chat-id', 'DHI economy')]);
    });

    testWidgets('if no title comes back, the chat is not renamed', (
      tester,
    ) async {
      final args = AppServicesArgs(ai: FakeAiService(pieces: ['Answer']));
      await pump(tester, args);
      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await settle(tester);

      expect(args.ai.titleRequests, hasLength(1));
      expect(args.chat.renames, isEmpty);
      expect(find.textContaining('went wrong'), findsNothing);
    });

    testWidgets('save appears only under Nova\'s answers, and saves it', (
      tester,
    ) async {
      final args = AppServicesArgs();
      await pump(tester, args, conversationId: 'c1');
      args.chat.messages.add(const [
        ChatMessage(id: 'm1', role: MessageRole.user, text: 'Question'),
        ChatMessage(id: 'm2', role: MessageRole.model, text: 'The answer'),
      ]);
      await tester.pump();

      expect(find.byTooltip('Save answer'), findsOneWidget);
      expect(find.byTooltip('Copy answer'), findsOneWidget);
      expect(find.byTooltip('Remember this'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Save answer'));
      await tester.pump();
      expect(args.saved.saved, [('c1', 'm2', 'My chat', 'The answer')]);
      expect(find.text('Saved'), findsOneWidget); // The short message.
      expect(find.byTooltip('Remove from Saved'), findsOneWidget);
    });
  });

  group('input box', () {
    testWidgets('a pasted link shows the hint before sending', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChatInput(onSend: (_, _) {}, isBusy: false)),
        ),
      );
      expect(find.text(linkHint), findsNothing);
      await tester.enterText(
        find.byType(TextField),
        'Summarise https://example.com/a',
      );
      await tester.pump();
      expect(find.text(linkHint), findsOneWidget);
    });

    testWidgets('every button has a label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChatInput(onSend: (_, _) {}, isBusy: false)),
        ),
      );
      expect(find.byTooltip('Send message'), findsOneWidget);
      expect(
        find.byTooltip('Attach image or PDF\nImages and PDFs, up to 7 MB'),
        findsOneWidget,
      );
    });
  });
}

/// The fakes one ChatScreen test uses.
class AppServicesArgs {
  AppServicesArgs({FakeAiService? ai})
    : ai = ai ?? FakeAiService(),
      chat = FakeChatRepository(),
      saved = FakeSavedRepository();
  final FakeAiService ai;
  final FakeChatRepository chat;
  final FakeSavedRepository saved;
}
