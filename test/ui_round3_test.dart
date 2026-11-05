// UI round 3: chat row menus, account name, chat width, input height.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/nova_tokens.dart';
import 'package:nova_chat/app/theme.dart';
import 'package:nova_chat/models/conversation.dart';
import 'package:nova_chat/screens/chat_shell.dart';
import 'package:nova_chat/widgets/chat_input.dart';
import 'package:nova_chat/widgets/sidebar.dart';

import 'fakes.dart';

void main() {
  group('account name', () {
    test('uses the display name when there is one', () {
      expect(accountName('Karma Y', 'karma@example.com'), 'Karma Y');
    });
    test('otherwise the part of the email before @', () {
      expect(accountName(null, 'karma@example.com'), 'karma');
      expect(accountName('  ', 'karma@example.com'), 'karma');
    });
    test('falls back when there is no email', () {
      expect(accountName(null, null), 'Signed in');
    });
  });

  Future<void> pumpShell(
    WidgetTester tester,
    Size size, {
    String? displayName,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChatShell(
          services: fakeServices(
            chat: FakeChatRepository(
              chats: const [
                Conversation(id: 'c1', title: 'Trip plans'),
                Conversation(id: 'c2', title: 'Recipes'),
              ],
            ),
          ),
          uid: 'user-a',
          email: 'karma@example.com',
          displayName: displayName,
        ),
      ),
    );
    await tester.pump();
  }

  Finder optionsIn(String title) => find.descendant(
    of: find.widgetWithText(ListTile, title),
    matching: find.byTooltip('Chat options'),
  );

  group('desktop chat rows', () {
    testWidgets('"…" hidden until hover', (tester) async {
      await pumpShell(tester, const Size(1200, 800));
      expect(optionsIn('Trip plans'), findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Trip plans')));
      await tester.pump();
      expect(optionsIn('Trip plans'), findsOneWidget);
      expect(optionsIn('Recipes'), findsNothing);

      await mouse.moveTo(const Offset(1100, 700)); // Off the sidebar.
      await tester.pump();
      expect(optionsIn('Trip plans'), findsNothing);
    });

    testWidgets('the selected chat shows a lime dot, not "…"', (tester) async {
      await pumpShell(tester, const Size(1200, 800));
      await tester.tap(find.text('Trip plans'));
      await tester.pump();
      final dotIn = find.descendant(
        of: find.widgetWithText(ListTile, 'Trip plans'),
        matching: find.byKey(const ValueKey('selected-dot')),
      );
      expect(dotIn, findsOneWidget);
      expect(optionsIn('Trip plans'), findsNothing);
    });
  });

  testWidgets('phone: no "…", long-press opens the menu', (tester) async {
    await pumpShell(tester, const Size(400, 800));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(optionsIn('Trip plans'), findsNothing);

    await tester.longPress(find.text('Trip plans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete chat'));
    await tester.pumpAndSettle();
    expect(find.text('Delete chat?'), findsOneWidget);
  });

  group('account area', () {
    testWidgets('shows the email name, full email in a tooltip', (
      tester,
    ) async {
      await pumpShell(tester, const Size(1200, 800));
      expect(find.text('karma'), findsOneWidget);
      expect(find.byTooltip('karma@example.com'), findsOneWidget);
    });

    testWidgets('shows the display name when there is one', (tester) async {
      await pumpShell(tester, const Size(1200, 800), displayName: 'Karma Y');
      expect(find.text('Karma Y'), findsOneWidget);
      expect(find.byTooltip('karma@example.com'), findsOneWidget);
    });
  });

  testWidgets('chat input is capped at the Studio column width', (
    tester,
  ) async {
    await pumpShell(tester, const Size(1600, 900));
    expect(
      tester.getSize(find.byType(ChatInput)).width,
      lessThanOrEqualTo(NovaSize.chatMaxWidth),
    );
  });

  testWidgets('input starts at one line and grows to 6', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatInput(onSend: (_, _) {}, isBusy: false)),
      ),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.minLines, 1);
    expect(field.maxLines, 6);
  });
}
