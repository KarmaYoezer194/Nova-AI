import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/artifact.dart';
import '../services/artifact_repository.dart';
import 'markdown_message.dart';
import '../app/nova_icons.dart';
import '../app/nova_tokens.dart';
import '../app/nova_typography.dart';

/// Shows one artifact, with Copy, Share and its saved versions.
///
/// Safety (security rule 6): documents are shown as SAFE Markdown (no HTML,
/// no images, links only on tap with a confirmation), and code is shown as
/// plain text. Nothing here is ever run.
class ArtifactPanel extends StatefulWidget {
  const ArtifactPanel({
    super.key,
    required this.artifact,
    required this.repository,
    required this.uid,
    required this.conversationId,
    required this.onClose,
  });

  /// The artifact that was opened (from a message).
  final ArtifactBlock artifact;
  final ArtifactRepository repository;
  final String uid;

  /// Null if the chat isn't saved yet (then there are no versions).
  final String? conversationId;
  final VoidCallback onClose;

  @override
  State<ArtifactPanel> createState() => _ArtifactPanelState();
}

class _ArtifactPanelState extends State<ArtifactPanel> {
  Stream<List<ArtifactVersion>>? _versions;

  /// The version picked in the menu. Null = the one that was opened.
  int? _pickedVersion;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(ArtifactPanel old) {
    super.didUpdateWidget(old);
    if (old.artifact.key != widget.artifact.key ||
        old.artifact.content != widget.artifact.content ||
        old.conversationId != widget.conversationId) {
      _pickedVersion = null;
      _watch();
    }
  }

  void _watch() {
    final cid = widget.conversationId;
    _versions = cid == null
        ? null
        : widget.repository.watchVersions(widget.uid, cid, widget.artifact.key);
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _copy(ArtifactBlock a) async {
    await Clipboard.setData(ClipboardData(text: a.content));
    if (mounted) _show('Copied');
  }

  /// Opens the system share sheet (phone) or the browser's share dialog.
  /// Where sharing isn't supported, copies instead. The email and download
  /// fallbacks are turned off so nothing unexpected opens.
  Future<void> _share(ArtifactBlock a) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: a.content,
          subject: a.title,
          title: a.title,
          mailToFallbackEnabled: false,
          downloadFallbackEnabled: false,
        ),
      );
      if (result.status != ShareResultStatus.unavailable) return;
    } catch (error) {
      if (kDebugMode) debugPrint('Share not available: $error');
    }
    await Clipboard.setData(ClipboardData(text: a.content));
    if (mounted) _show('Sharing isn\'t available here, so it was copied.');
  }

  @override
  Widget build(BuildContext context) {
    final versions = _versions;
    if (versions == null) return _build(context, widget.artifact, const []);
    return StreamBuilder<List<ArtifactVersion>>(
      stream: versions,
      builder: (context, snapshot) {
        if (snapshot.hasError && kDebugMode) {
          debugPrint('Artifact versions error: ${snapshot.error}');
        }
        final list = snapshot.data ?? const <ArtifactVersion>[];
        return _build(context, _current(list), list);
      },
    );
  }

  /// The version to show: the picked one, else the one matching what was
  /// opened, else the artifact itself.
  ArtifactBlock _current(List<ArtifactVersion> list) {
    for (final v in list) {
      if (v.version == _pickedVersion) return v.toBlock();
    }
    return widget.artifact;
  }

  int? _shownVersion(List<ArtifactVersion> list, ArtifactBlock shown) {
    if (_pickedVersion != null) return _pickedVersion;
    for (final v in list.reversed) {
      if (v.content == shown.content) return v.version;
    }
    return null;
  }

  Widget _build(
    BuildContext context,
    ArtifactBlock a,
    List<ArtifactVersion> versions,
  ) {
    final theme = Theme.of(context);
    final shownVersion = _shownVersion(versions, a);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Icon(
                  a.kind == ArtifactKind.code
                      ? NovaIcons.code
                      : NovaIcons.document,
                  size: NovaSize.iconLarge,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (versions.length > 1)
                  PopupMenuButton<int>(
                    tooltip: 'Versions',
                    initialValue: shownVersion,
                    onSelected: (v) => setState(() => _pickedVersion = v),
                    itemBuilder: (_) => [
                      for (final v in versions.reversed)
                        PopupMenuItem(
                          value: v.version,
                          child: Text('Version ${v.version}'),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            shownVersion == null
                                ? '${versions.length} versions'
                                : 'v$shownVersion of ${versions.length}',
                          ),
                          const Icon(NovaIcons.dropdown),
                        ],
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(NovaIcons.copy),
                  onPressed: () => _copy(a),
                ),
                IconButton(
                  tooltip: 'Share',
                  icon: const Icon(NovaIcons.share),
                  onPressed: () => _share(a),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(NovaIcons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: a.kind == ArtifactKind.code
                ? _CodeView(code: a.content, language: a.language)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: MarkdownMessage(text: a.content),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Code as plain, selectable text. Never run.
class _CodeView extends StatelessWidget {
  const _CodeView({required this.code, this.language});
  final String code;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (language != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  language!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(code, style: NovaText.of(context).code),
            ),
          ],
        ),
      ),
    );
  }
}
