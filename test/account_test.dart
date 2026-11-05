import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/theme.dart';
import 'package:nova_chat/screens/privacy_screen.dart';
import 'package:nova_chat/screens/settings_screen.dart';
import 'package:nova_chat/services/auth_service.dart';

import 'fakes.dart';

void main() {
  Future<void> openDeleteDialog(
    WidgetTester tester,
    FakeAccountService account,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SettingsScreen(
          services: fakeServices(account: account),
          uid: 'user-a',
          email: 'a@example.com',
        ),
      ),
    );
    await tester.pump(); // Settings finishes loading.
    await tester.pump();
    await tester.ensureVisible(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
  }

  testWidgets('deleting the account needs the password', (tester) async {
    final account = FakeAccountService(AuthService());
    await openDeleteDialog(tester, account);

    // Without a password nothing is deleted.
    await tester.tap(find.text('Delete forever'));
    await tester.pump();
    expect(find.text('Please enter your password.'), findsOneWidget);
    expect(account.deleted, isEmpty);

    await tester.enterText(find.byType(TextField).last, 'my-password');
    await tester.tap(find.text('Delete forever'));
    await tester.pumpAndSettle();
    expect(account.deleted.single, ('user-a', 'my-password'));
  });

  testWidgets('a wrong password shows a friendly message', (tester) async {
    final account = FakeAccountService(
      AuthService(),
      error: const AuthFailure('Email or password is incorrect.'),
    );
    await openDeleteDialog(tester, account);
    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.tap(find.text('Delete forever'));
    await tester.pumpAndSettle();
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.text('Delete your account?'), findsOneWidget); // Still open.
  });

  testWidgets('privacy note explains storage, files and Gemini free tier', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000); // Show every section.
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));
    expect(find.textContaining('never saved'), findsOneWidget);
    expect(find.textContaining('improve its products'), findsOneWidget);
    expect(find.textContaining('never put into'), findsOneWidget);
  });
}
