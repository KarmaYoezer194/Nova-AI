import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/constants.dart';
import '../models/conversation.dart';
import '../models/project.dart';
import '../services/project_repository.dart';
import '../app/nova_icons.dart';

/// What the user chose on the project page. Returned to the chat shell.
sealed class ProjectResult {
  const ProjectResult();
}

class StartChatInProject extends ProjectResult {
  const StartChatInProject(this.projectId);
  final String projectId;
}

class OpenProjectChat extends ProjectResult {
  const OpenProjectChat(this.chat);
  final Conversation chat;
}

/// One project: its name, instructions and notes, and its chats.
///
/// The instructions and notes are sent with every message in the project's
/// chats, so they are limited in size (shown by the counters).
class ProjectScreen extends StatefulWidget {
  const ProjectScreen({
    super.key,
    required this.services,
    required this.uid,
    required this.project,
  });

  final AppServices services;
  final String uid;
  final Project project;

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late final _name = TextEditingController(text: widget.project.name);
  late final _instructions = TextEditingController(
    text: widget.project.instructions,
  );
  late final _notes = TextEditingController(text: widget.project.notes);

  /// Last saved values, to know whether there are changes.
  late var _saved = (
    widget.project.name,
    widget.project.instructions,
    widget.project.notes,
  );
  bool _saving = false;

  // The project's chats, filtered from the user's chat list.
  late final Stream<List<Conversation>> _chats = widget.services.chat
      .watchConversations(widget.uid)
      .map(
        (all) => all
            .where((c) => c.projectId == widget.project.id && c.isVisible)
            .toList(),
      );

  ProjectRepository get _repo => widget.services.projects;

  bool get _changed =>
      (_name.text.trim(), _instructions.text.trim(), _notes.text.trim()) !=
      (_saved.$1.trim(), _saved.$2.trim(), _saved.$3.trim());

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.updateProject(
        widget.uid,
        widget.project.id,
        name: _name.text,
        instructions: _instructions.text,
        notes: _notes.text,
      );
      _saved = (_name.text, _instructions.text, _notes.text);
      _show('Saved. Used from the next message in this project.');
    } on ProjectException catch (e) {
      _show(e.message);
    } catch (error) {
      if (kDebugMode) debugPrint('Save project error: $error');
      _show('Couldn\'t save. Check your connection.');
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          '"${_saved.$1}" will be deleted, with its instructions '
          'and notes. Its chats are kept as normal chats. '
          'This can\'t be undone.',
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
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    try {
      await _repo.deleteProject(widget.uid, widget.project.id);
      navigator.pop();
    } catch (error) {
      if (kDebugMode) debugPrint('Delete project error: $error');
      _show('Couldn\'t delete the project. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_saved.$1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Delete project',
            icon: const Icon(NovaIcons.delete),
            onPressed: _delete,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.maxChatWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).pop(StartChatInProject(widget.project.id)),
                icon: const Icon(NovaIcons.add),
                label: const Text('New chat in this project'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 28),
              _field(
                controller: _name,
                label: 'Name',
                maxLength: AppConstants.maxProjectNameLength,
              ),
              const SizedBox(height: 12),
              Text('Instructions', style: theme.textTheme.titleMedium),
              _help(
                context,
                'How ${AppConstants.assistantName} should work in every '
                'chat of this project. For example: "I\'m preparing for my '
                'networking exam. Quiz me and explain my mistakes."',
              ),
              _field(
                controller: _instructions,
                maxLength: AppConstants.maxProjectInstructionsLength,
                minLines: 3,
                maxLines: 8,
              ),
              const SizedBox(height: 12),
              Text('Notes', style: theme.textTheme.titleMedium),
              _help(
                context,
                'Reference material, like a syllabus or a brief. Sent with '
                'every message in this project, so keep it short. '
                'Don\'t include passwords or private details.',
              ),
              _field(
                controller: _notes,
                maxLength: AppConstants.maxProjectNotesLength,
                minLines: 5,
                maxLines: 14,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _changed && !_saving ? _save : null,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ),
              const SizedBox(height: 28),
              Text('Chats in this project', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildChats(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _help(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required int maxLength,
    String? label,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildChats(BuildContext context) {
    return StreamBuilder<List<Conversation>>(
      stream: _chats,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Couldn\'t load the chats.');
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final chats = snapshot.data!;
        if (chats.isEmpty) return const Text('No chats yet.');
        return Column(
          children: [
            for (final chat in chats)
              ListTile(
                leading: const Icon(NovaIcons.chat),
                title: Text(
                  chat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).pop(OpenProjectChat(chat)),
              ),
          ],
        );
      },
    );
  }
}
