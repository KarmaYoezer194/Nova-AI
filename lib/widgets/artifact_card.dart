import 'package:flutter/material.dart';

import '../models/artifact.dart';
import '../app/nova_icons.dart';
import '../app/nova_tokens.dart';

/// The card shown in the chat in place of an artifact. Tapping it opens the
/// artifact in the side panel.
class ArtifactCard extends StatelessWidget {
  const ArtifactCard({super.key, required this.artifact, this.onOpen});

  final ArtifactBlock artifact;

  /// Null while the artifact is still being written.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final writing = !artifact.isComplete;
    final isCode = artifact.kind == ArtifactKind.code;
    final subtitle = writing
        ? 'Writing…'
        : isCode
        ? 'Code${artifact.language == null ? '' : ' · ${artifact.language}'}'
        : 'Document';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NovaRadius.button),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: writing ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(NovaRadius.sm),
                ),
                child: writing
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isCode ? NovaIcons.code : NovaIcons.document,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artifact.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!writing)
                Icon(
                  NovaIcons.openExternal,
                  size: NovaSize.icon,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
