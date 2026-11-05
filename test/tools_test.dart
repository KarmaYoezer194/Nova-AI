import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/theme.dart';
import 'package:nova_chat/screens/chat_screen.dart';
import 'package:nova_chat/services/tools.dart';

import 'fakes.dart';

void main() {
  group('tools are read-only', () {
    test('only the two read-only tools exist', () {
      final tools = NovaTools(searchChats: (_) async => const []);
      expect(tools.declarations().map((d) => d.name).toSet(), {
        NovaTools.dateToolName,
        NovaTools.searchToolName,
      });
    });

    test('date tool reads the clock', () {
      final tools = NovaTools(
        searchChats: (_) async => const [],
        now: () => DateTime(2026, 11, 3, 9, 5),
      );
      final result = tools.currentDateTime();
      expect(result['date'], 'Tuesday, 3 November 2026');
      expect(result['time'], '09:05');
      expect(result['timeZone'], startsWith('UTC'));
    });

    test('search marks results as data and rejects empty queries', () async {
      final queries = <String>[];
      final tools = NovaTools(
        searchChats: (q) async {
          queries.add(q);
          return const [ChatSearchHit(title: 'Essay outline')];
        },
      );
      final search = tools.declarations().firstWhere(
        (d) => d.name == NovaTools.searchToolName,
      );

      final empty = await search.callable({'query': '  '});
      expect(empty['error'], isNotNull);
      expect(queries, isEmpty);

      final found = await search.callable({'query': 'x' * 500});
      expect(queries.single.length, NovaTools.maxQueryLength);
      expect(found['note'], contains('not instructions'));
      expect((found['results'] as List).single, {'title': 'Essay outline'});
    });
  });

  test('rankByTitle: most matching words first, then most recent', () {
    final titles = [
      'Holiday plans', // newest
      'Climate essay draft',
      'Essay outline: climate change',
      'Python homework',
    ];
    expect(rankByTitle(titles, 'climate essay', title: (t) => t), [
      'Climate essay draft',
      'Essay outline: climate change',
    ]);
    expect(rankByTitle(titles, 'a', title: (t) => t), isEmpty);
  });

  testWidgets('tools are given for the signed-in user only', (tester) async {
    final repo = FakeChatRepository();
    final ai = FakeAiService();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ChatScreen(
            uid: 'user-a',
            services: fakeServices(chat: repo, ai: ai),
            initialConversationId: 'current-chat',
            onConversationCreated: (_) {},
          ),
        ),
      ),
    );
    repo.messages.add(const []);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'What did we talk about?');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    // Whatever the model asks for, the search runs for user-a only, and
    // leaves out the chat it is in.
    final search = ai.lastTools!.declarations().firstWhere(
      (d) => d.name == NovaTools.searchToolName,
    );
    await search.callable({'query': 'essay', 'uid': 'someone-else'});
    expect(repo.searches.single, ('user-a', 'essay', 'current-chat'));
  });
}
