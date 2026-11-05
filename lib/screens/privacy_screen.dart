import 'package:flutter/material.dart';

import '../app/constants.dart';

/// A short, plain-language privacy note (Phase 12).
///
/// This describes what the app actually does. It is not a legal policy;
/// a public release would need one.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'What is saved',
      'Your chats, the answers, your custom instructions, memories, projects, '
          'saved answers, your thumbs up / down ratings and saved artifact versions are stored in your own private area '
          'of our database (Google Cloud Firestore). Only you can read them: '
          'the database rules block everyone else.',
    ),
    (
      'Photos and PDFs',
      'Files you attach are sent to the AI with that one message and are '
          'never saved. Only a note like "Photo attached: notes.png" is kept.',
    ),
    (
      'Links you paste',
      'When a message contains a web link, Google opens that page (the app '
          'doesn\'t download it) so ${AppConstants.assistantName} can read '
          'it. Only public pages work: pages that need a sign-in or a '
          'subscription can\'t be read. Don\'t paste private links, such as '
          'shared documents or links with passwords or codes in them. '
          'When you ask about the news, Nova also reads Wikipedia\'s public '
          '"Current events" page the same way.',
    ),
    (
      'Who processes your messages',
      'To answer you, your message, recent chat history, custom instructions, '
          'memories and project notes are sent to Google\'s Gemini AI through '
          'Firebase. ${AppConstants.appName} uses Gemini\'s free tier, where '
          'Google says it may use what is sent to improve its products, and '
          'people at Google may review it. So please don\'t share passwords, '
          'health, money or other private details.',
    ),
    (
      'What is not shared',
      'Your email address and account details are never put into the AI\'s '
          'instructions. ${AppConstants.assistantName} can\'t send, post, '
          'buy or delete anything: it only writes text.',
    ),
    (
      'Security',
      'Requests must come from the real app (Firebase App Check) and from a '
          'signed-in user. There are no secret keys inside the app.',
    ),
    (
      'Your choices',
      'Delete single chats from the sidebar, memories and instructions in '
          'Settings, or your whole account and all its data in Settings → '
          'Delete account. Deleting is permanent.',
    ),
    (
      'Mistakes',
      '${AppConstants.assistantName} can make mistakes. Check important '
          'information before you rely on it.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.maxChatWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'How ${AppConstants.appName} handles your data',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'A short summary for testers. Last updated 4 November 2026.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              for (final (title, body) in _sections) ...[
                const SizedBox(height: 24),
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(body, style: theme.textTheme.bodyLarge),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
