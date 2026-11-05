import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/constants.dart';
import '../models/saved_item.dart';
import '../app/nova_icons.dart';

/// The "Saved" list: answers the user bookmarked, newest first.
///
/// Tapping an item closes this page and returns it, so the shell can open
/// its chat at that message.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key, required this.services, required this.uid});

  final AppServices services;
  final String uid;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  late final Stream<List<SavedItem>> _saved = widget.services.saved.watchSaved(
    widget.uid,
  );

  Future<void> _remove(SavedItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.services.saved.remove(
        widget.uid,
        item.conversationId,
        item.messageId,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Removed from Saved'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Remove saved error: $error');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t remove it. Check your connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.maxChatWidth,
          ),
          child: StreamBuilder<List<SavedItem>>(
            stream: _saved,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                if (kDebugMode) debugPrint('Saved error: ${snapshot.error}');
                return const Center(
                  child: Text('Couldn\'t load your saved answers.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Nothing saved yet. Tap the bookmark under one of '
                    '${AppConstants.assistantName}\'s answers to keep it here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return ListTile(
                    leading: const Icon(NovaIcons.saved),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item.preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    onTap: () => Navigator.of(context).pop(item),
                    trailing: IconButton(
                      tooltip: 'Remove from Saved',
                      icon: const Icon(NovaIcons.delete),
                      onPressed: () => _remove(item),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
