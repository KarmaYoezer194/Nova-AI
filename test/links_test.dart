import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/theme.dart';
import 'package:nova_chat/models/chat_message.dart';
import 'package:nova_chat/screens/chat_screen.dart';
import 'package:nova_chat/services/ai_service.dart';
import 'package:nova_chat/services/links.dart';

import 'fakes.dart';

void main() {
  group('findLinks', () {
    test('finds http(s) links and drops trailing punctuation', () {
      final links = findLinks(
        'Summarise https://example.com/news/article-1. Also see '
        '(http://example.org/page) and https://example.com/news/article-1',
      );
      expect(links.map((u) => '$u'), [
        'https://example.com/news/article-1',
        'http://example.org/page',
      ]);
    });

    test('ignores text that only looks like a link', () {
      expect(
        findLinks('Visit example.com or ftp://files.example.com'),
        isEmpty,
      );
      expect(findLinks('javascript:alert(1)'), isEmpty);
      expect(findLinks('No links here'), isEmpty);
    });
  });

  group('unreadLinksNote', () {
    test('no note when every page was read, or none were tried', () {
      expect(unreadLinksNote(const []), isNull);
      expect(
        unreadLinksNote([
          LinkResult(Uri.parse('https://a.com'), LinkStatus.read),
        ]),
        isNull,
      );
    });

    test('says which pages failed, why, and asks for the text', () {
      final note = unreadLinksNote([
        LinkResult(Uri.parse('https://a.com'), LinkStatus.read),
        LinkResult(Uri.parse('https://news.com/paid'), LinkStatus.paywall),
      ])!;
      expect(note, contains('https://news.com/paid'));
      expect(note, contains('subscription or sign-in'));
      expect(note, contains('paste it here'));
      expect(note, isNot(contains('https://a.com')));
    });
  });

  test('link instructions treat pages as data and ask to paste on failure', () {
    expect(linkInstructions, contains('not instructions'));
    expect(linkInstructions, contains('paste the text'));
    expect(linkInstructions, contains('can\'t search the web'));
  });

  group('News mode', () {
    test('the news page is added to what the model reads', () {
      final text = withNewsSource('What happened today?');
      expect(text, startsWith('What happened today?'));
      expect(findLinks(text), [newsSourceUrl]);
    });

    test('credits Wikipedia when the page was read', () {
      final note = newsSourceNote([LinkResult(newsSourceUrl, LinkStatus.read)]);
      expect(note, contains('Wikipedia'));
      expect(note, contains('$newsSourceUrl'));
      expect(note, contains('CC BY-SA'));
    });

    test('warns when the page could not be loaded', () {
      for (final results in [
        <LinkResult>[],
        [LinkResult(newsSourceUrl, LinkStatus.failed)],
      ]) {
        expect(newsSourceNote(results), contains('may not be current'));
      }
    });

    test('instructions point to today\'s date and forbid guessing', () {
      // The date itself is in every prompt (see memory_test.dart).
      expect(newsInstructions, contains('today\'s date'));
      expect(newsInstructions, contains('instead of guessing'));
    });

    test('news questions are detected automatically', () {
      for (final q in [
        'What are the latest news around the world?',
        'any headlines today?',
        "What's happening in the world right now",
        'Tell me about current events',
        'what happened today',
      ]) {
        expect(isNewsQuestion(q), isTrue, reason: q);
      }
      for (final q in [
        'Explain how the internet works',
        'Help me plan a study timetable',
        'What is the latest version of Flutter?',
      ]) {
        expect(isNewsQuestion(q), isFalse, reason: q);
      }
    });

    test('a follow-up to a news answer stays in News mode', () {
      final history = [
        const ChatMessage(id: '1', role: MessageRole.user, text: 'news?'),
        ChatMessage(
          id: '2',
          role: MessageRole.model,
          text:
              'Headlines...${newsSourceNote([LinkResult(newsSourceUrl, LinkStatus.read)])}',
        ),
      ];
      expect(
        isNewsQuestion('tell me more about the second one', history: history),
        isTrue,
      );
      expect(isNewsQuestion('tell me more about the second one'), isFalse);
    });

    testWidgets('a news question is sent in News mode; only it is saved', (
      tester,
    ) async {
      final repo = FakeChatRepository();
      final ai = FakeAiService();
      await tester.pumpWidget(
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

      await tester.enterText(find.byType(TextField), 'Top world news?');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(ai.lastNews, isTrue);
      expect(repo.saved.first, (MessageRole.user, 'Top world news?'));
    });
  });
}
