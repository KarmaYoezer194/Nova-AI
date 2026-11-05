import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/constants.dart';
import '../models/conversation.dart';
import '../models/project.dart';
import '../models/saved_item.dart';
import '../services/project_repository.dart';
import '../widgets/sidebar.dart';
import 'chat_screen.dart';
import 'project_screen.dart';
import 'saved_screen.dart';
import 'settings_screen.dart';
import '../app/nova_colors.dart';
import '../app/nova_icons.dart';
import '../app/nova_tokens.dart';
import '../app/nova_typography.dart';
import '../widgets/nova/nova_icon_button.dart';
import '../widgets/nova/nova_menu.dart';
import '../widgets/nova/nova_project.dart';

/// The main signed-in layout.
///
/// Wide screens (900 px or more): sidebar always visible on the left.
/// Narrow screens (phones): sidebar slides out from a menu button.
class ChatShell extends StatefulWidget {
  const ChatShell({
    super.key,
    required this.services,
    required this.uid,
    required this.email,
    this.displayName,
  });

  final AppServices services;
  final String uid;
  final String? email;

  /// The name on the sign-in account, if it has one.
  final String? displayName;

  @override
  State<ChatShell> createState() => _ChatShellState();
}

class _ChatShellState extends State<ChatShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Wide screens: the user hid the sidebar (top bar shows Show sidebar).
  bool _sidebarHidden = false;

  /// The chat shown on the right. Null = a new, empty chat.
  String? _selectedId;

  /// Changes when the user picks a different chat (or New chat), so the chat
  /// screen starts fresh. It does NOT change when a new chat gets its id,
  /// so an answer that is streaming keeps going.
  int _session = 0;

  /// The project of the chat on the right (or of the new chat about to be
  /// started). Null = not in a project.
  String? _projectId;

  /// The user's chats (null while loading), kept here so both the sidebar
  /// and the chat (for its title) can use them.
  List<Conversation>? _chats;
  bool _chatsFailed = false;
  StreamSubscription<List<Conversation>>? _chatsSub;

  /// Opened from Saved: the message the chat should scroll to.
  String? _targetMessageId;

  /// The user's projects (null while loading). Kept here so both the
  /// sidebar and the chat's project label can use them.
  List<Project>? _projects;
  StreamSubscription<List<Project>>? _projectsSub;

  @override
  void initState() {
    super.initState();
    // Start fetching instructions and memories now, not on the first send.
    widget.services.memory.preload(widget.uid);
    _chatsSub = widget.services.chat
        .watchConversations(widget.uid)
        .listen(
          (list) {
            if (mounted) setState(() => _chats = list);
          },
          onError: (Object error) {
            if (kDebugMode) debugPrint('Chats error: $error');
            if (mounted) setState(() => _chatsFailed = true);
          },
        );
    _projectsSub = widget.services.projects
        .watchProjects(widget.uid)
        .listen(
          (list) {
            if (mounted) setState(() => _projects = list);
          },
          onError: (Object error) {
            if (kDebugMode) debugPrint('Projects error: $error');
            if (mounted) setState(() => _projects = const []);
          },
        );
  }

  @override
  void dispose() {
    // This screen closes on sign-out.
    widget.services.memory.stopWatching();
    _projectsSub?.cancel();
    _chatsSub?.cancel();
    widget.services.projects.clearCache();
    super.dispose();
  }

  void _closeDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState!.closeDrawer();
    }
  }

  /// Opens a chat ([id]), or a new chat when [id] is null. A new chat goes
  /// into [projectId] if given. With [messageId], the chat scrolls to that
  /// message (opened from Saved).
  void _openChat(String? id, {String? projectId, String? messageId}) {
    _closeDrawer();
    if (id == _selectedId && id != null && messageId == null) return;
    setState(() {
      _selectedId = id;
      _projectId = projectId;
      _targetMessageId = messageId;
      _session++;
    });
  }

  String? _titleOf(String? id) {
    if (id == null) return null;
    for (final c in _chats ?? const <Conversation>[]) {
      if (c.id == id) return c.title;
    }
    return null;
  }

  Future<void> _openSaved() async {
    _closeDrawer();
    final item = await Navigator.of(context).push<SavedItem>(
      MaterialPageRoute(
        builder: (_) => SavedScreen(services: widget.services, uid: widget.uid),
      ),
    );
    if (!mounted || item == null) return;
    String? projectId;
    for (final c in _chats ?? const <Conversation>[]) {
      if (c.id == item.conversationId) projectId = c.projectId;
    }
    _openChat(
      item.conversationId,
      projectId: projectId,
      messageId: item.messageId,
    );
  }

  Project? _projectById(String? id) {
    if (id == null) return null;
    for (final p in _projects ?? const <Project>[]) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _openProject(Project project) async {
    _closeDrawer();
    final result = await Navigator.of(context).push<ProjectResult>(
      MaterialPageRoute(
        builder: (_) => ProjectScreen(
          services: widget.services,
          uid: widget.uid,
          project: project,
        ),
      ),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case StartChatInProject(:final projectId):
        _openChat(null, projectId: projectId);
      case OpenProjectChat(:final chat):
        _openChat(chat.id, projectId: chat.projectId);
    }
  }

  Future<void> _newProject() async {
    _closeDrawer();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewProjectDialog(),
    );
    if (name == null || !mounted) return;
    try {
      final id = await widget.services.projects.createProject(widget.uid, name);
      if (!mounted) return;
      await _openProject(Project(id: id, name: cleanProjectName(name)));
    } on ProjectException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (error) {
      if (kDebugMode) debugPrint('Create project error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t create the project. Try again.'),
        ),
      );
    }
  }

  void _openSettings() {
    _closeDrawer();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          services: widget.services,
          uid: widget.uid,
          email: widget.email,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Conversation chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
          '"${chat.title}" and all its messages will be deleted. '
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
    if (confirmed != true) return;

    if (chat.id == _selectedId) _openChat(null);
    try {
      await widget.services.chat.deleteConversation(widget.uid, chat.id);
    } catch (error) {
      if (kDebugMode) debugPrint('Delete error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t delete the chat. Try again.')),
      );
    }
  }

  // ---------- Top bar: the open chat's title and "…" menu ----------

  /// The chat on the right, or null for a new, empty chat.
  Conversation? get _currentChat {
    final id = _selectedId;
    if (id == null) return null;
    for (final c in _chats ?? const <Conversation>[]) {
      if (c.id == id) return c;
    }
    // Just created and not answered yet (so not in the list).
    return Conversation(id: id, title: 'New chat', projectId: _projectId);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _rename(Conversation chat) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: chat.title),
    );
    if (title == null || title == chat.title) return;
    try {
      await widget.services.chat.renameConversation(widget.uid, chat.id, title);
    } catch (error) {
      if (kDebugMode) debugPrint('Rename error: $error');
      _showError('Couldn\'t rename the chat. Try again.');
    }
  }

  Future<void> _move(Conversation chat) async {
    // A record, so "No project" (null) can be told apart from Cancel.
    final choice = await showDialog<({String? id})>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Move to project'),
        children: [
          for (final (id, name) in [
            (null, 'No project'),
            for (final p in _projects ?? const <Project>[]) (p.id, p.name),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop((id: id)),
              child: Row(
                children: [
                  Icon(
                    id == chat.projectId
                        ? NovaIcons.check
                        : (id == null ? NovaIcons.chat : NovaIcons.folder),
                    size: NovaSize.iconLarge,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
        ],
      ),
    );
    if (choice == null || choice.id == chat.projectId) return;
    try {
      await widget.services.chat.moveConversation(
        widget.uid,
        chat.id,
        choice.id,
      );
      // The open chat now uses the new project's instructions and notes.
      if (mounted && chat.id == _selectedId) {
        setState(() => _projectId = choice.id);
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Move error: $error');
      _showError('Couldn\'t move the chat. Try again.');
    }
  }

  /// "…" menu for the open chat: Rename, Move to project, Delete.
  Widget _chatMenu(Conversation chat) => Builder(
    builder: (anchor) => NovaIconButton(
      tooltip: 'Chat options',
      icon: NovaIcons.more,
      kind: NovaIconButtonKind.control,
      shape: NovaIconButtonShape.square,
      onPressed: () async {
        final action = await showMenuAt<String>(anchor, items: _menuItems);
        switch (action) {
          case 'rename':
            await _rename(chat);
          case 'move':
            await _move(chat);
          case 'delete':
            await _confirmDelete(chat);
        }
      },
    ),
  );

  static const List<PopupMenuEntry<String>> _menuItems = [
    PopupMenuItem(
      value: 'rename',
      child: ListTile(leading: Icon(NovaIcons.edit), title: Text('Rename')),
    ),
    PopupMenuItem(
      value: 'move',
      child: ListTile(
        leading: Icon(NovaIcons.moveToProject),
        title: Text('Move to project'),
      ),
    ),
    PopupMenuItem(
      value: 'delete',
      child: ListTile(
        leading: Icon(NovaIcons.delete),
        title: Text('Delete chat'),
      ),
    ),
  ];

  /// The bar at the top of the main panel on wide screens: Show sidebar
  /// (when hidden), the chat's title, its project pill, and the chat menu
  /// at the right. A new chat has no title bar (the greeting is the title).
  Widget? _topBar(BuildContext context, Conversation? chat, Project? project) {
    if (chat == null && !_sidebarHidden) return null;
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(
        minHeight: NovaSize.iconButton + NovaSpace.xl,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: NovaSpace.lg,
        vertical: NovaSpace.md,
      ),
      child: Row(
        children: [
          if (_sidebarHidden) ...[
            NovaIconButton(
              tooltip: 'Show sidebar',
              icon: NovaIcons.collapseSidebar,
              kind: NovaIconButtonKind.control,
              shape: NovaIconButtonShape.square,
              onPressed: () => setState(() => _sidebarHidden = false),
            ),
            const SizedBox(width: NovaSpace.sm),
            NovaIconButton(
              tooltip: 'New chat',
              icon: NovaIcons.add,
              kind: NovaIconButtonKind.accent,
              onPressed: () => _openChat(null),
            ),
            const SizedBox(width: NovaSpace.md),
          ] else
            const SizedBox(width: NovaSpace.sm),
          // Title and pill take the free space, so the menu sits at the
          // right edge.
          Expanded(
            child: Row(
              children: [
                if (chat != null)
                  Flexible(
                    child: Text(
                      chat.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                if (chat != null && project != null) ...[
                  const SizedBox(width: NovaSpace.md),
                  Flexible(
                    child: NovaProjectPill(
                      project: project,
                      onPressed: () => _openProject(project),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (chat != null) _chatMenu(chat),
        ],
      ),
    );
  }

  /// The phone top bar's title: the chat's title, with its project's name
  /// underneath in the project's colour.
  Widget _phoneTitle(
    BuildContext context,
    Conversation? chat,
    Project? project,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          chat?.title ?? 'New chat',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        if (project != null)
          Text(
            project.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NovaText.of(context).caption.copyWith(
              color: NovaColors.of(context).forProject(project.id).label,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentChat;
    Sidebar sidebar({required bool wide}) => Sidebar(
      email: widget.email,
      displayName: widget.displayName,
      hoverMenus: wide,
      onCollapse: wide ? () => setState(() => _sidebarHidden = true) : null,
      conversations: _chats,
      chatsFailed: _chatsFailed,
      projects: _projects,
      selectedId: _selectedId,
      onNewChat: () => _openChat(null),
      onSelect: (c) => _openChat(c.id, projectId: c.projectId),
      onDelete: _confirmDelete,
      onSignOut: widget.services.auth.signOut,
      onOpenSettings: _openSettings,
      onOpenProject: _openProject,
      onNewProject: _newProject,
      onOpenSaved: _openSaved,
    );

    // If the project was deleted, the top bar simply shows no project.
    final project = _projectById(_projectId);
    final chat = ChatScreen(
      key: ValueKey(_session),
      uid: widget.uid,
      services: widget.services,
      initialConversationId: _selectedId,
      initialMessageId: _targetMessageId,
      chatTitle: _titleOf(_selectedId),
      projectId: _projectId,
      displayName: widget.displayName,
      greetingName: greetingNameFrom(widget.displayName, widget.email),
      onConversationCreated: (id) {
        if (mounted) setState(() => _selectedId = id);
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide =
            constraints.maxWidth >= AppConstants.wideLayoutBreakpoint;

        if (isWide) {
          // Two floating panels on the dark background.
          final c = NovaColors.of(context);
          final panelShape = BorderRadius.circular(NovaRadius.panel);
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: c.background,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(NovaSpace.appPadding),
                child: Row(
                  children: [
                    if (!_sidebarHidden) ...[
                      SizedBox(
                        width: NovaSize.sidebarWidth,
                        child: ClipRRect(
                          borderRadius: panelShape,
                          child: sidebar(wide: true),
                        ),
                      ),
                      const SizedBox(width: NovaSpace.panelGap),
                    ],
                    Expanded(
                      child: ClipRRect(
                        borderRadius: panelShape,
                        child: Material(
                          color: c.mainPanel,
                          child: Column(
                            children: [
                              ?_topBar(context, current, project),
                              Expanded(child: chat),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            titleSpacing: 0,
            title: _phoneTitle(context, current, project),
            actions: [
              NovaIconButton(
                tooltip: 'New chat',
                icon: NovaIcons.add,
                kind: NovaIconButtonKind.accent,
                onPressed: () => _openChat(null),
              ),
              if (current != null) ...[
                const SizedBox(width: NovaSpace.xs + 2),
                _chatMenu(current),
              ],
              const SizedBox(width: NovaSpace.sm),
            ],
          ),
          drawer: Drawer(
            width: NovaSize.sidebarWidth,
            child: sidebar(wide: false),
          ),
          body: chat,
        );
      },
    );
  }
}

/// Asks for a new project's name. Returns it, or null if cancelled.
class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog();

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New project'),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _name,
          autofocus: true,
          maxLength: AppConstants.maxProjectNameLength,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'For example: Networking exam',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _create(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _create,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Asks for a chat's new title. Returns it, or null if cancelled.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});
  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _title = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isNotEmpty) Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename chat'),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _title,
          autofocus: true,
          maxLength: AppConstants.maxTitleLength,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _title.text.trim().isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
