import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/screens/sign_in_screen.dart';
import 'package:nova_chat/services/auth_service.dart';

void main() {
  group('friendlyAuthMessage', () {
    test('wrong email and wrong password give the same message', () {
      final a = friendlyAuthMessage('user-not-found');
      final b = friendlyAuthMessage('wrong-password');
      final c = friendlyAuthMessage('invalid-credential');
      expect(a, b);
      expect(b, c);
    });

    test('unknown codes get a generic message, never the raw code', () {
      final message = friendlyAuthMessage('some-new-internal-code');
      expect(message, isNot(contains('some-new-internal-code')));
    });
  });

  group('validators', () {
    test('email', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('not-an-email'), isNotNull);
      expect(validateEmail('  a@b.co  '), isNull);
    });

    test('new password needs at least 8 characters', () {
      expect(validateNewPassword('1234567'), isNotNull);
      expect(validateNewPassword('12345678'), isNull);
    });
  });

  group('SignInScreen', () {
    Future<void> pumpScreen(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(home: SignInScreen(authService: AuthService())),
      );
    }

    testWidgets('empty form shows errors and does not call Firebase', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('can switch to registration mode', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pump();

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      // Show / hide on both password fields.
      expect(find.byTooltip('Show password'), findsNWidgets(2));
      expect(
        find.widgetWithText(FilledButton, 'Create account'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Sign in instead'));
      await tester.tap(find.text('Sign in instead'));
      await tester.pump();
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('registration rejects mismatched passwords', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'a@b.co');
      await tester.enterText(fields.at(1), 'password123');
      await tester.enterText(fields.at(2), 'password124');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pump();

      expect(find.text('Passwords don\'t match.'), findsOneWidget);
    });
  });
}
