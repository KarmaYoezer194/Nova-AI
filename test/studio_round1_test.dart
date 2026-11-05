// Studio redesign, round 1: theme, tokens, logo and base widgets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/nova_colors.dart';
import 'package:nova_chat/app/nova_icons.dart';
import 'package:nova_chat/app/nova_tokens.dart';
import 'package:nova_chat/app/nova_typography.dart';
import 'package:nova_chat/app/theme.dart';
import 'package:nova_chat/widgets/nova/nova_button.dart';
import 'package:nova_chat/widgets/nova/nova_card.dart';
import 'package:nova_chat/widgets/nova/nova_chip.dart';
import 'package:nova_chat/widgets/nova/nova_icon_button.dart';
import 'package:nova_chat/widgets/nova/nova_logo.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('the theme is dark and carries the Studio colours and styles', () {
    final t = AppTheme.dark;
    expect(t.brightness, Brightness.dark);
    expect(t.colorScheme.primary, NovaColors.studio.accent);
    expect(t.extension<NovaColors>(), isNotNull);
    expect(t.extension<NovaText>(), isNotNull);
    expect(t.textTheme.titleLarge?.fontFamily, contains('SpaceGrotesk'));
    expect(t.textTheme.bodyMedium?.fontFamily, contains('DMSans'));
    expect(t.extension<NovaText>()!.code.fontFamily, contains('DMMono'));
  });

  group('project colours', () {
    test('the hash is the standard FNV-1a (same on web and phones)', () {
      expect(stableHash(''), 0x811c9dc5);
      expect(stableHash('a'), 0xe40c292c);
      expect(stableHash('foobar'), 0xbf9cf968);
    });

    test('a project always gets the same colour, and both are used', () {
      const c = NovaColors.studio;
      final ids = [for (var i = 0; i < 20; i++) 'project-$i'];
      final first = [for (final id in ids) c.forProject(id).dot];
      final again = [for (final id in ids) c.forProject(id).dot];
      expect(again, first);
      expect(first.toSet(), {c.projectOrange, c.projectTeal});
    });
  });

  testWidgets('logo shows at the asked size', (tester) async {
    await tester.pumpWidget(_app(const NovaLogo(size: NovaSize.logoHero)));
    expect(
      tester.getSize(find.byType(NovaLogo)),
      const Size.square(NovaSize.logoHero),
    );
  });

  testWidgets('icon buttons are 44 px, have a tooltip, and disable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const NovaIconButton(
          icon: NovaIcons.send,
          tooltip: 'Send message',
          onPressed: null,
          kind: NovaIconButtonKind.accent,
        ),
      ),
    );
    expect(find.byTooltip('Send message'), findsOneWidget);
    expect(
      tester.getSize(find.byType(IconButton)),
      const Size.square(NovaSize.iconButton),
    );
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
  });

  testWidgets('buttons are 48 px tall (52 large) and tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NovaButton(label: 'Sign in', large: true, onPressed: () => taps++),
            NovaButton.secondary(label: 'Create an account', onPressed: () {}),
          ],
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      NovaSize.buttonLarge,
    );
    expect(tester.getSize(find.byType(OutlinedButton)).height, NovaSize.button);
    await tester.tap(find.text('Sign in'));
    expect(taps, 1);
  });

  testWidgets('chips are easy to tap (48 px touch area)', (tester) async {
    await tester.pumpWidget(
      _app(NovaChip(label: 'Networking exam', onPressed: () {})),
    );
    expect(
      tester.getSize(find.byType(OutlinedButton)).height,
      greaterThanOrEqualTo(NovaSize.minTouchTarget),
    );
  });

  testWidgets('cards can be tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(NovaCard(onTap: () => taps++, child: const Text('Plan my week'))),
    );
    await tester.tap(find.text('Plan my week'));
    expect(taps, 1);
  });
}
