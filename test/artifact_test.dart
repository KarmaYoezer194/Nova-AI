import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/theme.dart';
import 'package:nova_chat/models/artifact.dart';
import 'package:nova_chat/models/chat_message.dart';
import 'package:nova_chat/screens/chat_screen.dart';
import 'package:nova_chat/widgets/message_bubble.dart';

import 'fakes.dart';

const outline =
    'Here is your outline.\n\n'
    '<artifact title="Essay outline: Climate" kind="document">\n'
    '# Climate\n\n1. Introduction\n2. Causes\n'
    '</artifact>\n\n'
    'Want me to expand any part?';

void main() {
  group('parseSegments', () {
    test('splits text and a finished artifact', () {
      final s = parseSegments(outline);
      expect(s, hasLength(3));
      expect((s[0] as TextSegment).text, 'Here is your outline.');
      final a = (s[1] as ArtifactSegment).artifact;
      expect(a.title, 'Essay outline: Climate');
      expect(a.kind, ArtifactKind.document);
      expect(a.content, '# Climate\n\n1. Introduction\n2. Causes');
      expect(a.isComplete, isTrue);
      expect((s[2] as TextSegment).text, 'Want me to expand any part?');
    });

    test('while streaming, an unclosed artifact is marked unfinished', () {
      final s = parseSegments('Sure!\n<artifact title="Plan">\n# Day 1');
      final a = (s.last as ArtifactSegment).artifact;
      expect(a.isComplete, isFalse);
      expect(a.content, '# Day 1');
    });

    test('a half-written tag at the end is hidden', () {
      final s = parseSegments('Here it comes <artif');
      expect((s.single as TextSegment).text, 'Here it comes');
    });

    test('code: language kept, ``` fences removed, odd language dropped', () {
      final code =
          parseSegments(
                '<artifact title="Hi" kind="code" '
                'language="Python">\n```python\nprint("hi")\n```\n</artifact>',
              ).single
              as ArtifactSegment;
      expect(code.artifact.kind, ArtifactKind.code);
      expect(code.artifact.language, 'python');
      expect(code.artifact.content, 'print("hi")');

      final odd =
          parseSegments(
                '<artifact title="x" kind="code" '
                'language="<script>">a</artifact>',
              ).single
              as ArtifactSegment;
      expect(odd.artifact.language, isNull);
    });

    test('same title = same artifact (for versions)', () {
      expect(
        artifactKey('Essay Outline: Climate!'),
        artifactKey('essay outline climate'),
      );
    });

    test('Copy text has no tags', () {
      final text = plainText(outline);
      expect(text, isNot(contains('<artifact')));
      expect(text, contains('Essay outline: Climate'));
      expect(text, contains('2. Causes'));
    });
  });

  testWidgets('an artifact shows as a card, not as raw tags', (tester) async {
    ArtifactBlock? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            role: MessageRole.model,
            text: outline,
            onOpenArtifact: (a) => opened = a,
          ),
        ),
      ),
    );
    expect(find.textContaining('<artifact'), findsNothing);
    expect(find.text('Essay outline: Climate'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);

    await tester.tap(find.text('Essay outline: Climate'));
    expect(opened?.title, 'Essay outline: Climate');
  });

  testWidgets(
    'wide screen: a finished artifact opens in the panel and is saved',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final artifacts = FakeArtifactRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ChatScreen(
              uid: 'user-a',
              services: fakeServices(
                ai: FakeAiService(pieces: [outline]),
                artifacts: artifacts,
              ),
              initialConversationId: null,
              onConversationCreated: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Outline an essay');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(artifacts.saved.single.title, 'Essay outline: Climate');
      // The panel: Copy, Share and Close buttons, and the formatted outline.
      expect(find.byTooltip('Share'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.text('Causes'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      expect(find.byTooltip('Share'), findsNothing);
    },
  );
}
