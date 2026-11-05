import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/theme.dart';
import 'package:nova_chat/widgets/markdown_message.dart';

void main() {
  Future<void> pump(WidgetTester tester, String markdown) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(child: MarkdownMessage(text: markdown)),
        ),
      ),
    );
  }

  testWidgets('headings and bold are formatted, not shown as symbols', (
    tester,
  ) async {
    await pump(tester, '### Steps\n\nThis is **important**.');

    expect(find.textContaining('###'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('Steps'), findsOneWidget);
  });

  testWidgets('code blocks show the language and a Copy button', (
    tester,
  ) async {
    await pump(tester, '```dart\nprint("hi");\n```');

    expect(find.text('dart'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.textContaining('print("hi");'), findsOneWidget);
  });

  testWidgets('images are never loaded from the internet', (tester) async {
    await pump(tester, '![tracker](https://evil.example/pixel.png)');

    expect(find.byType(Image), findsNothing);
    expect(find.text('[image: tracker]'), findsOneWidget);
  });

  testWidgets('HTML is shown as text, never rendered', (tester) async {
    await pump(tester, 'Hello <b>there</b> <script>alert(1)</script>');

    // No crash and no web view; the raw tags appear as plain text.
    expect(find.textContaining('Hello'), findsOneWidget);
  });
}
