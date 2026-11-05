import 'package:flutter/material.dart';

import '../app/constants.dart';
import '../app/nova_colors.dart';
import '../app/nova_icons.dart';
import '../app/nova_tokens.dart';
import '../app/nova_typography.dart';
import 'nova/nova_card.dart';
import 'nova/nova_logo.dart';

/// What a new, empty chat shows (Studio design): the logo, a greeting by
/// time of day, the big composer, and three suggestion cards.
class EmptyChat extends StatelessWidget {
  const EmptyChat({
    super.key,
    required this.composer,
    required this.onPromptTap,
    this.firstName,
    this.now,
  });

  /// The big message box (a ChatInput), placed under the greeting.
  final Widget composer;

  /// Called with the prompt text when a suggestion is tapped.
  final ValueChanged<String> onPromptTap;

  /// For "Good evening, John". Without it: "Good evening".
  final String? firstName;

  /// For tests; otherwise the device's time.
  final DateTime? now;

  /// Below this width the cards stack in one column.
  static const double _cardsInRow = 600;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = NovaColors.of(context);
    final name = firstName?.trim() ?? '';
    final greeting = name.isEmpty
        ? greetingFor(now ?? DateTime.now())
        : '${greetingFor(now ?? DateTime.now())}, $name';

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < _cardsInRow;
        final cards = [
          for (final s in _suggestions(c))
            _SuggestionCard(suggestion: s, onTap: () => onPromptTap(s.prompt)),
        ];
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(NovaSpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: NovaSize.chatMaxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NovaLogo(size: NovaSize.logoHero),
                  const SizedBox(height: NovaSpace.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      greeting,
                      style: narrow
                          ? theme.textTheme.headlineLarge
                          : theme.textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: NovaSpace.sm),
                  Text(
                    'What are we working on today?',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: NovaSpace.xl),
                  composer,
                  const SizedBox(height: NovaSpace.lg),
                  if (narrow)
                    for (final card in cards)
                      Padding(
                        padding: const EdgeInsets.only(bottom: NovaSpace.md),
                        child: SizedBox(width: double.infinity, child: card),
                      )
                  else
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: NovaSpace.md),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The app's example prompts, each with a title, icon and tint.
  static List<_Suggestion> _suggestions(NovaColors c) {
    const prompts = AppConstants.examplePrompts;
    return [
      _Suggestion(
        'Explain a topic',
        prompts[0],
        NovaIcons.explain,
        c.accent,
        c.accentTile,
      ),
      _Suggestion(
        'Plan my week',
        prompts[1],
        NovaIcons.calendar,
        c.projectOrange,
        c.projectOrangeTile,
      ),
      _Suggestion(
        'Get ideas',
        prompts[2],
        NovaIcons.ideas,
        c.projectTeal,
        c.projectTealTile,
      ),
    ];
  }
}

/// "Good morning" before noon, "Good afternoon" until 6 pm, then
/// "Good evening".
String greetingFor(DateTime time) {
  if (time.hour < 12) return 'Good morning';
  if (time.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class _Suggestion {
  const _Suggestion(this.title, this.prompt, this.icon, this.color, this.tile);
  final String title;
  final String prompt;
  final IconData icon;
  final Color color;
  final Color tile;
}

/// One suggestion: an icon on a tinted square, a title and the prompt.
/// Tapping it sends the prompt.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onTap});

  final _Suggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = NovaText.of(context);
    return Semantics(
      button: true,
      label: '${suggestion.title}: ${suggestion.prompt}',
      excludeSemantics: true,
      child: NovaCard(
        radius: NovaRadius.suggestion,
        padding: const EdgeInsets.all(NovaSpace.lg + 2),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: NovaSize.iconButton - 10,
              height: NovaSize.iconButton - 10,
              decoration: BoxDecoration(
                color: suggestion.tile,
                borderRadius: BorderRadius.circular(NovaRadius.sm + 2),
              ),
              child: Icon(
                suggestion.icon,
                size: NovaSize.icon,
                color: suggestion.color,
              ),
            ),
            const SizedBox(height: NovaSpace.lg),
            Text(suggestion.title, style: text.cardTitle),
            const SizedBox(height: NovaSpace.xs + 2),
            Text(suggestion.prompt, style: text.small),
          ],
        ),
      ),
    );
  }
}
