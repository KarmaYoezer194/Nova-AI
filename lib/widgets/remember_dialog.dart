import 'package:flutter/material.dart';

import '../app/constants.dart';

/// Asks the user what to remember. Returns the text, or null if cancelled.
///
/// The box is pre-filled (for example from a message) but the user always
/// sees and can edit exactly what will be saved. Nothing is saved without
/// this confirmation.
Future<String?> showRememberDialog(
  BuildContext context, {
  String initialText = '',
  String title = 'Remember this?',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _RememberDialog(initialText: initialText, title: title),
  );
}

class _RememberDialog extends StatefulWidget {
  const _RememberDialog({required this.initialText, required this.title});
  final String initialText;
  final String title;

  @override
  State<_RememberDialog> createState() => _RememberDialogState();
}

class _RememberDialogState extends State<_RememberDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A short fact ${AppConstants.assistantName} will use in all '
              'your chats. Edit it so it says exactly what you mean.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: AppConstants.maxMemoryLength,
              decoration: const InputDecoration(
                hintText: 'For example: I\'m learning Flutter',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            Text(
              'Don\'t save passwords or private details.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
