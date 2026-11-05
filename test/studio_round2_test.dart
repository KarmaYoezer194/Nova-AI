// Studio redesign, round 2: app shell, sidebar and top bars.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/theme.dart';
import 'package:nova_chat/models/conversation.dart';
import 'package:nova_chat/models/project.dart';
import 'package:nova_chat/screens/chat_shell.dart';
import 'package:nova_chat/widgets/nova/nova_project.dart';

import 'fakes.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester,
    Size size, {
    List<Project> projects = const [],
    List<Conversation> chats = const [
      Conversation(id: 'c1', title: 'Trip plans', projectId: 'p0'),
      Conversation(id: 'c2', title: 'Recipes'),
    ],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChatShell(
          services: fakeServices(
            chat: FakeChatRepository(chats: chats),
            projects: FakeProjectRepository(projects: projects),
          ),
          uid: 'user-a',
          email: 'karma@example.com',
        ),
      ),
    );
    await tester.pump();
  }

  List<Project> projectsN(int n) => [
    for (var i = 0; i < n; i++) Project(id: 'p$i', name: 'Project $i'),
  ];

  testWidgets('at most 4 project tiles, then "See all projects"', (
    tester,
  ) async {
    await pumpShell(tester, const Size(1200, 900), projects: projectsN(6));
    expect(find.byType(NovaProjectTile), findsNWidgets(4));

    await tester.tap(find.text('See all projects (6)'));
    await tester.pump();
    expect(find.byType(NovaProjectTile), findsNWidgets(6));

    await tester.tap(find.text('Show fewer'));
    await tester.pump();
    expect(find.byType(NovaProjectTile), findsNWidgets(4));
  });

  testWidgets('no "See all" link with 4 projects or fewer', (tester) async {
    await pumpShell(tester, const Size(1200, 900), projects: projectsN(4));
    expect(find.byType(NovaProjectTile), findsNWidgets(4));
    expect(find.textContaining('See all projects'), findsNothing);
  });

  testWidgets('a project tile opens the project page', (tester) async {
    await pumpShell(tester, const Size(1200, 900), projects: projectsN(1));
    await tester.tap(find.byType(NovaProjectTile));
    await tester.pumpAndSettle();
    expect(find.text('Project 0'), findsWidgets);
    expect(find.byType(NovaProjectTile), findsNothing); // A new page.
  });

  testWidgets('account row: name, email, one button for Settings and '
      'Sign out', (tester) async {
    await pumpShell(tester, const Size(1200, 900));
    expect(find.text('karma'), findsOneWidget);
    expect(find.text('karma@example.com'), findsOneWidget);
    expect(find.text('Saved answers'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings and sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('the sidebar can be hidden and shown again', (tester) async {
    await pumpShell(tester, const Size(1200, 900));
    await tester.tap(find.byTooltip('Hide sidebar'));
    await tester.pump();
    expect(find.text('Saved answers'), findsNothing);

    await tester.tap(find.byTooltip('Show sidebar'));
    await tester.pump();
    expect(find.text('Saved answers'), findsOneWidget);
  });

  testWidgets('wide: the chat menu sits at the right edge of the top bar', (
    tester,
  ) async {
    await pumpShell(tester, const Size(1200, 900));
    await tester.tap(find.text('Recipes'));
    await tester.pump();
    final menu = tester.getRect(find.byTooltip('Chat options').last);
    expect(menu.right, greaterThan(1200 - 80));
  });

  testWidgets('wide: the open chat shows its project pill in the top bar', (
    tester,
  ) async {
    await pumpShell(tester, const Size(1200, 900), projects: projectsN(1));
    await tester.tap(find.text('Trip plans'));
    await tester.pump();
    expect(find.widgetWithText(NovaProjectPill, 'Project 0'), findsOneWidget);
  });

  testWidgets('phone: menu, title with project, lime New chat and "…"', (
    tester,
  ) async {
    await pumpShell(tester, const Size(400, 800), projects: projectsN(1));
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    expect(find.byTooltip('New chat'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trip plans'));
    // Not pumpAndSettle: the chat's loading spinner never settles.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The drawer closed; the bar shows the title and project name.
    expect(find.text('Trip plans'), findsOneWidget);
    expect(find.text('Project 0'), findsOneWidget);
    expect(find.byTooltip('Chat options'), findsOneWidget);
  });
}
