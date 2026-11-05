import 'package:flutter/material.dart';

import '../app/constants.dart';
import '../app/nova_colors.dart';
import '../app/nova_icons.dart';
import '../app/nova_tokens.dart';
import '../app/nova_typography.dart';
import '../models/conversation.dart';
import '../models/project.dart';
import 'nova/nova_button.dart';
import 'nova/nova_icon_button.dart';
import 'nova/nova_logo.dart';
import 'nova/nova_menu.dart';
import 'nova/nova_project.dart';

/// The left sidebar (Studio design), top to bottom: logo and Hide sidebar,
/// New chat and Search, a grid of projects, recent chats, Saved answers,
/// and the account row (its button opens Settings and Sign out).
class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.email,
    required this.conversations,
    required this.projects,
    required this.selectedId,
    required this.onNewChat,
    required this.onSelect,
    required this.onDelete,
    required this.onSignOut,
    required this.onOpenSettings,
    required this.onOpenProject,
    required this.onNewProject,
    required this.onOpenSaved,
    this.displayName,
    this.chatsFailed = false,
    this.hoverMenus = true,
    this.onCollapse,
  });

  /// Wide screens: hides the sidebar. Null (phones): no button.
  final VoidCallback? onCollapse;

  final String? email;

  /// The name on the sign-in account, if it has one.
  final String? displayName;

  /// Wide screens: a chat's "…" shows on hover or keyboard focus.
  /// Phones (false): no "…"; a long-press opens the same menu.
  final bool hoverMenus;

  /// The user's chats, newest first, or null while loading.
  final List<Conversation>? conversations;

  /// True if the chats couldn't be loaded.
  final bool chatsFailed;

  /// The user's projects, or null while loading.
  final List<Project>? projects;
  final String? selectedId;
  final VoidCallback onNewChat;
  final ValueChanged<Conversation> onSelect;
  final ValueChanged<Conversation> onDelete;
  final VoidCallback onSignOut;
  final VoidCallback onOpenSettings;
  final ValueChanged<Project> onOpenProject;
  final VoidCallback onNewProject;
  final VoidCallback onOpenSaved;

  /// How many project tiles show before "See all projects".
  static const int maxProjectTiles = 4;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final _search = TextEditingController();

  /// The search box shows after tapping the Search button.
  bool _searchOpen = false;

  /// "See all projects" was tapped.
  bool _allProjects = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() => setState(() {
    _searchOpen = !_searchOpen;
    if (!_searchOpen) _search.clear();
  });

  bool get _searching => _search.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    final text = NovaText.of(context);

    return Material(
      color: c.panel,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NovaSpace.lg + NovaSpace.xs,
                NovaSpace.lg + NovaSpace.xs,
                NovaSpace.lg,
                NovaSpace.lg,
              ),
              child: Row(
                children: [
                  const NovaLogo(hero: true),
                  const SizedBox(width: NovaSpace.sm + 2),
                  // The logo word, lowercase. Screen readers say "Nova".
                  Semantics(
                    label: AppConstants.appName,
                    excludeSemantics: true,
                    child: Text(
                      AppConstants.appName.toLowerCase(),
                      style: text.logo,
                    ),
                  ),
                  const Spacer(),
                  if (widget.onCollapse != null)
                    NovaIconButton(
                      tooltip: 'Hide sidebar',
                      icon: NovaIcons.collapseSidebar,
                      kind: NovaIconButtonKind.control,
                      shape: NovaIconButtonShape.square,
                      onPressed: widget.onCollapse,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: NovaSpace.lg),
              child: Row(
                children: [
                  Expanded(
                    child: NovaButton(
                      label: 'New chat',
                      icon: NovaIcons.add,
                      onPressed: widget.onNewChat,
                      expand: true,
                    ),
                  ),
                  const SizedBox(width: NovaSpace.sm),
                  NovaIconButton(
                    icon: NovaIcons.search,
                    tooltip: _searchOpen ? 'Close search' : 'Search chats',
                    kind: NovaIconButtonKind.control,
                    shape: NovaIconButtonShape.square,
                    isSelected: _searchOpen,
                    onPressed: _toggleSearch,
                  ),
                ],
              ),
            ),
            if (_searchOpen) _searchBox(context),
            Expanded(child: _buildLists(context)),
            _accountRow(context),
          ],
        ),
      ),
    );
  }

  Widget _searchBox(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NovaSpace.lg,
        NovaSpace.sm,
        NovaSpace.lg,
        0,
      ),
      child: TextField(
        controller: _search,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search chats',
          counterText: '',
          prefixIcon: const Icon(NovaIcons.search, size: NovaSize.icon),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  iconSize: NovaSize.icon,
                  icon: const Icon(NovaIcons.close),
                  onPressed: _search.clear,
                ),
        ),
      ),
    );
  }

  /// Projects and chats in one scrolling list.
  Widget _buildLists(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NovaSpace.lg,
        0,
        NovaSpace.lg,
        NovaSpace.md,
      ),
      children: [
        _header(
          context,
          'Projects',
          trailing: NovaIconButton(
            tooltip: 'New project',
            icon: NovaIcons.add,
            onPressed: widget.onNewProject,
          ),
        ),
        ..._projectGrid(context),
        _header(context, 'Recent'),
        ..._chatTiles(context),
        const SizedBox(height: NovaSpace.md),
        _SavedRow(onTap: widget.onOpenSaved),
      ],
    );
  }

  /// A section label ("PROJECTS", "RECENT"), read as a heading.
  Widget _header(BuildContext context, String title, {Widget? trailing}) {
    return Padding(
      padding: EdgeInsets.only(
        left: NovaSpace.xs,
        top: trailing == null ? NovaSpace.xl : NovaSpace.lg,
        bottom: trailing == null ? NovaSpace.sm : 0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              label: title,
              excludeSemantics: true,
              child: Text(
                title.toUpperCase(),
                style: NovaText.of(context).sectionLabel,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  /// Up to [Sidebar.maxProjectTiles] projects in two columns, then a link
  /// to show the rest.
  List<Widget> _projectGrid(BuildContext context) {
    final list = widget.projects;
    if (list == null) return const [];
    if (list.isEmpty) {
      return [_hint(context, 'Group chats and give them shared instructions.')];
    }
    final shown = _allProjects
        ? list
        : list.take(Sidebar.maxProjectTiles).toList();
    Widget tile(Project p) =>
        NovaProjectTile(project: p, onTap: () => widget.onOpenProject(p));

    return [
      for (var i = 0; i < shown.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: NovaSpace.sm),
          child: Row(
            children: [
              Expanded(child: tile(shown[i])),
              const SizedBox(width: NovaSpace.sm),
              Expanded(
                child: i + 1 < shown.length
                    ? tile(shown[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      if (list.length > Sidebar.maxProjectTiles)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _allProjects = !_allProjects),
            child: Text(
              _allProjects ? 'Show fewer' : 'See all projects (${list.length})',
            ),
          ),
        ),
    ];
  }

  /// Every chat, newest first. Chats in a project show its colour.
  List<Widget> _chatTiles(BuildContext context) {
    if (widget.chatsFailed) {
      return [_hint(context, 'Couldn\'t load your chats.')];
    }
    final all = widget.conversations;
    if (all == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(NovaSpace.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final projectIds = {for (final p in widget.projects ?? const []) p.id};
    final chats = filterChats(all, _search.text);
    if (chats.isEmpty) {
      return [
        _hint(
          context,
          _searching
              ? 'No chats match "${_search.text.trim()}".'
              : 'Your chats will appear here.',
        ),
      ];
    }
    return [
      for (final chat in chats)
        _ChatTile(
          // Keyed by chat, so hover state doesn't jump to another row.
          key: ValueKey(chat.id),
          chat: chat,
          // Only for projects that still exist.
          projectId: projectIds.contains(chat.projectId)
              ? chat.projectId
              : null,
          selected: chat.id == widget.selectedId,
          hoverMenu: widget.hoverMenus,
          onSelect: () => widget.onSelect(chat),
          onDelete: () => widget.onDelete(chat),
        ),
    ];
  }

  Widget _hint(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NovaSpace.xs,
        NovaSpace.xs,
        NovaSpace.xs,
        NovaSpace.sm,
      ),
      child: Text(message, style: NovaText.of(context).caption),
    );
  }

  /// Avatar, name and email, and one button with Settings and Sign out.
  Widget _accountRow(BuildContext context) {
    final c = NovaColors.of(context);
    final text = NovaText.of(context);
    final name = accountName(widget.displayName, widget.email);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NovaSpace.lg + NovaSpace.xs,
        NovaSpace.md,
        NovaSpace.lg + NovaSpace.xs,
        NovaSpace.lg + NovaSpace.xs,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: NovaSize.avatar,
              height: NovaSize.avatar,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.projectOrange,
                borderRadius: BorderRadius.circular(NovaRadius.sm + 2),
              ),
              child: Text(
                _initial(name),
                style: text.cardTitle.copyWith(color: c.onAccent),
              ),
            ),
          ),
          const SizedBox(width: NovaSpace.md - 2),
          Expanded(
            child: Tooltip(
              // The full email, for when it's cut off.
              message: widget.email ?? '',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.rowSelected,
                  ),
                  if (widget.email != null)
                    Text(
                      widget.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.caption,
                    ),
                ],
              ),
            ),
          ),
          Builder(
            builder: (anchor) => NovaIconButton(
              tooltip: 'Settings and sign out',
              icon: NovaIcons.account,
              kind: NovaIconButtonKind.control,
              shape: NovaIconButtonShape.square,
              onPressed: () => _openAccountMenu(anchor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAccountMenu(BuildContext anchor) async {
    final choice = await showMenuAt<String>(
      anchor,
      items: const [
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(NovaIcons.settings),
            title: Text('Settings'),
          ),
        ),
        PopupMenuItem(
          value: 'signOut',
          child: ListTile(
            leading: Icon(NovaIcons.signOut),
            title: Text('Sign out'),
          ),
        ),
      ],
    );
    switch (choice) {
      case 'settings':
        widget.onOpenSettings();
      case 'signOut':
        widget.onSignOut();
    }
  }

  static String _initial(String name) =>
      name.isEmpty ? '?' : name[0].toUpperCase();
}

/// The name shown in the account area: the account's display name, or the
/// part of the email before "@".
String accountName(String? displayName, String? email) {
  final name = displayName?.trim() ?? '';
  if (name.isNotEmpty) return name;
  final mail = email?.trim() ?? '';
  if (mail.isEmpty) return 'Signed in';
  final at = mail.indexOf('@');
  return at > 0 ? mail.substring(0, at) : mail;
}

/// The first word of the name shown in the account area, for the
/// new-chat greeting. Null if there's no name at all.
String? greetingNameFrom(String? displayName, String? email) {
  final display = displayName?.trim() ?? '';
  if (display.isNotEmpty) return display.split(RegExp(r'\s+')).first;
  final mail = email?.trim() ?? '';
  final at = mail.indexOf('@');
  if (at <= 0) return null;
  // "john.smith42@…" reads better as "John".
  final word = mail
      .substring(0, at)
      .split(RegExp(r'[._\-+0-9]'))
      .firstWhere((w) => w.isNotEmpty, orElse: () => '');
  if (word.isEmpty) return null;
  return word[0].toUpperCase() + word.substring(1);
}

/// "Saved answers" as a row with a dashed outline.
class _SavedRow extends StatelessWidget {
  const _SavedRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    final shape = BorderRadius.circular(NovaRadius.row);
    return CustomPaint(
      painter: _DashedBorderPainter(color: c.outline, radius: NovaRadius.row),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: NovaSize.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: NovaSpace.md),
              child: Row(
                children: [
                  Icon(NovaIcons.save, size: NovaSize.icon, color: c.textMuted),
                  const SizedBox(width: NovaSpace.sm + 2),
                  Text('Saved answers', style: NovaText.of(context).row),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws a dashed rounded-rectangle outline (decoration only).
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 5, _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = (Offset.zero & size).deflate(0.5);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// One chat row. A project chat shows the project's colour on the left; the
/// open chat shows a lime dot on the right. The "…" menu takes the dot's
/// place on hover or keyboard focus (wide screens), and a long-press opens
/// the same menu everywhere.
class _ChatTile extends StatefulWidget {
  const _ChatTile({
    super.key,
    required this.chat,
    required this.projectId,
    required this.selected,
    required this.hoverMenu,
    required this.onSelect,
    required this.onDelete,
  });

  final Conversation chat;
  final String? projectId;
  final bool selected;
  final bool hoverMenu;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  bool _hovered = false;
  bool _focused = false;
  bool _menuOpen = false;

  bool get _showButton =>
      widget.hoverMenu && (_hovered || _focused || _menuOpen);

  Future<void> _openMenu(BuildContext anchor) async {
    setState(() => _menuOpen = true);
    final choice = await showMenuAt<String>(
      anchor,
      items: const [PopupMenuItem(value: 'delete', child: Text('Delete chat'))],
    );
    if (mounted) setState(() => _menuOpen = false);
    if (choice == 'delete') widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final c = NovaColors.of(context);
    final text = NovaText.of(context);
    final Widget? trailing;
    if (_showButton) {
      trailing = Builder(
        builder: (buttonContext) => NovaIconButton(
          tooltip: 'Chat options',
          icon: NovaIcons.more,
          onPressed: () => _openMenu(buttonContext),
        ),
      );
    } else if (widget.selected) {
      trailing = Padding(
        padding: const EdgeInsets.only(right: NovaSpace.sm),
        child: Container(
          key: const ValueKey('selected-dot'),
          width: NovaSize.dot,
          height: NovaSize.dot,
          decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
        ),
      );
    } else {
      trailing = null;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      // Tracks focus anywhere in the row (the row or its "…" button), so
      // keyboard users can Tab to the button without it vanishing.
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => setState(() => _focused = f),
        child: Semantics(
          onLongPressHint: 'Show chat options',
          child: Builder(
            builder: (rowContext) => ListTile(
              dense: true,
              minTileHeight: NovaSize.minTouchTarget,
              contentPadding: const EdgeInsets.only(
                left: NovaSpace.md,
                right: NovaSpace.xs,
              ),
              selected: widget.selected,
              horizontalTitleGap: NovaSpace.sm,
              minLeadingWidth: 0,
              leading: widget.projectId == null
                  ? null
                  : ProjectSwatch(
                      projectId: widget.projectId!,
                      size: NovaSize.swatchSmall,
                    ),
              title: Text(
                widget.chat.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: widget.selected ? text.rowSelected : text.row,
              ),
              onTap: widget.onSelect,
              onLongPress: () => _openMenu(rowContext),
              trailing: trailing,
            ),
          ),
        ),
      ),
    );
  }
}

/// The chats shown in the list: only chats with an answer, and (if
/// [query] isn't empty) only those whose title contains it. Titles only,
/// ignoring upper/lower case.
List<Conversation> filterChats(List<Conversation> chats, String query) {
  final q = query.trim().toLowerCase();
  return [
    for (final c in chats)
      if (c.isVisible && (q.isEmpty || c.title.toLowerCase().contains(q))) c,
  ];
}
