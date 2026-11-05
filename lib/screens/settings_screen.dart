import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/constants.dart';
import '../models/memory.dart';
import '../services/auth_service.dart';
import '../services/memory_repository.dart';
import '../widgets/remember_dialog.dart';
import 'onboarding_screen.dart';
import 'privacy_screen.dart';
import '../app/nova_icons.dart';

/// Settings: what Nova should know about the user, and their memories.
///
/// Everything here is the user's own choice to share. It is sent with every
/// message, so the sizes are limited, and the user can delete all of it.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.services,
    required this.uid,
    this.email,
  });

  final AppServices services;
  final String uid;

  /// Shown in the Account section only (never sent to the AI).
  final String? email;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _instructions = TextEditingController();
  late final Stream<List<Memory>> _memories = widget.services.memory
      .watchMemories(widget.uid);

  /// The instructions as last saved, to know whether there are changes.
  String _savedInstructions = '';
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  MemoryRepository get _repo => widget.services.memory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final text = await _repo.loadCustomInstructions(widget.uid);
      if (!mounted) return;
      setState(() {
        _savedInstructions = text;
        _instructions.text = text;
        _loading = false;
      });
    } catch (error) {
      if (kDebugMode) debugPrint('Settings load error: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Couldn\'t load your settings. Check your connection.';
      });
    }
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _saveInstructions() async {
    setState(() => _saving = true);
    try {
      await _repo.saveCustomInstructions(widget.uid, _instructions.text);
      _savedInstructions = _instructions.text.trim();
      _show('Saved. Used from your next message.');
    } on MemoryException catch (e) {
      _show(e.message);
    } catch (error) {
      if (kDebugMode) debugPrint('Save instructions error: $error');
      _show('Couldn\'t save. Check your connection.');
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _addMemory() async {
    final text = await showRememberDialog(context, title: 'Add a memory');
    if (text == null) return;
    try {
      await _repo.addMemory(widget.uid, text);
    } on MemoryException catch (e) {
      _show(e.message);
    } catch (error) {
      if (kDebugMode) debugPrint('Add memory error: $error');
      _show('Couldn\'t save that. Check your connection.');
    }
  }

  Future<void> _deleteMemory(Memory memory) async {
    try {
      await _repo.deleteMemory(widget.uid, memory.id);
    } catch (error) {
      if (kDebugMode) debugPrint('Delete memory error: $error');
      _show('Couldn\'t delete. Try again.');
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
          'This deletes all your memories and your custom instructions. '
          'It can\'t be undone. Your chats are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteAllMemories(widget.uid);
      await _repo.saveCustomInstructions(widget.uid, '');
      if (!mounted) return;
      setState(() {
        _savedInstructions = '';
        _instructions.clear();
      });
      _show('Deleted.');
    } catch (error) {
      if (kDebugMode) debugPrint('Delete all error: $error');
      _show('Couldn\'t delete everything. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppConstants.maxChatWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_loadError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _loadError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    _buildInstructions(context),
                    const SizedBox(height: 32),
                    _buildMemories(context),
                    const SizedBox(height: 32),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _deleteAll,
                        icon: const Icon(NovaIcons.deleteForever),
                        label: const Text(
                          'Delete all memories and instructions',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildAccount(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAccount(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Account', style: theme.textTheme.titleMedium),
        if (widget.email != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Signed in as ${widget.email}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(NovaIcons.welcomeTour),
          title: const Text('Show welcome tour'),
          subtitle: Text(
            'What ${AppConstants.assistantName} can do, in three steps',
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (tourContext) => OnboardingScreen(
                replay: true,
                onFinish: (_) => Navigator.of(tourContext).pop(),
              ),
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(NovaIcons.privacy),
          title: const Text('Privacy'),
          subtitle: const Text('What is saved and who processes it'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            NovaIcons.deleteAccount,
            color: theme.colorScheme.error,
          ),
          title: Text(
            'Delete account',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          subtitle: const Text('Deletes your account and all your data'),
          onTap: _deleteAccount,
        ),
      ],
    );
  }

  Future<void> _deleteAccount() async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _DeleteAccountDialog(services: widget.services, uid: widget.uid),
    );
    if (deleted != true || !mounted) return;
    // Back to the first screen, which now shows the sign-in page.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildInstructions(BuildContext context) {
    final theme = Theme.of(context);
    final changed = _instructions.text.trim() != _savedInstructions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What should ${AppConstants.assistantName} know about you?',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'For example what you study, and how you like answers (short, '
          'detailed, with examples). Sent with every message. '
          'Don\'t include passwords or private details.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _instructions,
          minLines: 4,
          maxLines: 10,
          maxLength: AppConstants.maxCustomInstructionsLength,
          decoration: const InputDecoration(
            hintText:
                'I\'m a beginner programmer. Explain things simply '
                'and give short code examples.',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: changed && !_saving ? _saveInstructions : null,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ),
      ],
    );
  }

  Widget _buildMemories(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Memory>>(
      stream: _memories,
      builder: (context, snapshot) {
        final memories = snapshot.data ?? const <Memory>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Memories', style: theme.textTheme.titleMedium),
                ),
                Text(
                  '${memories.length} of ${AppConstants.maxMemories}',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Short facts ${AppConstants.assistantName} uses in all your '
              'chats. Only you can add them: tap "Remember" under a message, '
              'or add one here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (snapshot.hasError)
              const Text('Couldn\'t load your memories.')
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (memories.isEmpty)
              Text('No memories yet.', style: theme.textTheme.bodyMedium)
            else
              for (final m in memories)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(m.text),
                    trailing: IconButton(
                      tooltip: 'Delete memory',
                      icon: const Icon(NovaIcons.delete),
                      onPressed: () => _deleteMemory(m),
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: memories.length >= AppConstants.maxMemories
                  ? null
                  : _addMemory,
              icon: const Icon(NovaIcons.add),
              label: const Text('Add memory'),
            ),
          ],
        );
      },
    );
  }
}

/// Asks for the password, then deletes the account and all data.
/// Returns true when everything was deleted.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.services, required this.uid});
  final AppServices services;
  final String uid;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Please enter your password.');
      return;
    }
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.services.account.deleteAccountAndData(
        widget.uid,
        _password.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (error) {
      if (kDebugMode) debugPrint('Delete account error: $error');
      if (mounted) {
        setState(
          () => _error =
              'Couldn\'t delete everything. Check your connection and try '
              'again. Nothing you still see has been lost.',
        );
      }
    }
    if (mounted) setState(() => _deleting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your account and ALL your data: '
              'chats, answers, artifacts, memories, instructions and '
              'projects. It can\'t be undone.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_deleting,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Your password, to confirm',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _delete(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (_deleting)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _deleting ? null : _delete,
          child: const Text('Delete forever'),
        ),
      ],
    );
  }
}
