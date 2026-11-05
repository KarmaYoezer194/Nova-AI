import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/artifact.dart';
import '../models/attachment.dart';
import '../models/chat_message.dart';
import '../services/feedback_repository.dart';
import 'artifact_card.dart';
import 'markdown_message.dart';
import 'typing_indicator.dart';
import 'nova/nova_card.dart';
import 'nova/nova_icon_button.dart';
import 'nova/nova_logo.dart';
import '../app/constants.dart';
import '../app/nova_colors.dart';
import '../app/nova_tokens.dart';
import '../app/nova_icons.dart';
import '../app/nova_typography.dart';

/// One message in the chat.
///
/// User messages: a lime bubble on the right.
/// Nova's answers: a card with the logo and "Nova" on top, the answer, and
/// the action buttons once the answer is complete.
///
/// Safety: user text is plain text; Nova's text is safe Markdown. Nothing is
/// ever run as code or HTML (security rule 6).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.role,
    required this.text,
    this.isStreaming = false,
    this.attachmentKind,
    this.attachmentName,
    this.previewBytes,
    this.onRemember,
    this.onOpenArtifact,
    this.isSaved = false,
    this.onToggleSave,
    this.rating,
    this.onRate,
    this.onRegenerate,
    this.onEdit,
  });

  /// Nova's answers: the user's thumbs up / down (null = none), and what
  /// happens when one is tapped.
  final Rating? rating;
  final ValueChanged<Rating>? onRate;

  /// Latest answer only: ask the same question again.
  final VoidCallback? onRegenerate;

  /// The user's latest message only: put it back in the input box.
  final VoidCallback? onEdit;

  /// Shows a "Remember this" button when set (saved messages only).
  final VoidCallback? onRemember;

  /// Nova's answers only: shows a bookmark that saves the answer to the
  /// "Saved" list (filled when [isSaved]). Tapping again removes it.
  final VoidCallback? onToggleSave;
  final bool isSaved;

  /// Called when an artifact card in Nova's answer is tapped.
  final ValueChanged<ArtifactBlock>? onOpenArtifact;

  final MessageRole role;
  final String text;

  /// True while Nova's answer is still arriving.
  final bool isStreaming;

  /// Set when the user attached a file to this message.
  final AttachmentKind? attachmentKind;
  final String? attachmentName;

  /// The photo itself, only during the session it was sent in (files are
  /// never stored). Without it, a small "photo attached" note is shown.
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    return role == MessageRole.user
        ? _UserBubble(
            text: text,
            attachmentKind: attachmentKind,
            attachmentName: attachmentName,
            previewBytes: previewBytes,
            onRemember: onRemember,
            onEdit: onEdit,
          )
        : _ModelMessage(
            text: text,
            isStreaming: isStreaming,
            onRemember: onRemember,
            onOpenArtifact: onOpenArtifact,
            isSaved: isSaved,
            onToggleSave: onToggleSave,
            rating: rating,
            onRate: onRate,
            onRegenerate: onRegenerate,
          );
  }
}

/// A small grey icon button under a message. The tooltip is also what
/// screen readers announce.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selectedIcon,
    this.isSelected,
  });
  final String tooltip;
  final IconData icon;
  final IconData? selectedIcon;
  final bool? isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => NovaIconButton(
    tooltip: tooltip,
    isSelected: isSelected,
    icon: icon,
    selectedIcon: selectedIcon,
    onPressed: onPressed,
  );
}

class _RememberButton extends StatelessWidget {
  const _RememberButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => NovaIconButton(
    // The tooltip is also what screen readers announce.
    tooltip: 'Remember this',
    icon: NovaIcons.remember,
    onPressed: onPressed,
  );
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isSaved, required this.onPressed});
  final bool isSaved;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => NovaIconButton(
    tooltip: isSaved ? 'Remove from Saved' : 'Save answer',
    isSelected: isSaved,
    icon: NovaIcons.save,
    selectedIcon: NovaIcons.saved,
    onPressed: onPressed,
  );
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.text,
    this.attachmentKind,
    this.attachmentName,
    this.previewBytes,
    this.onRemember,
    this.onEdit,
  });

  final String text;
  final AttachmentKind? attachmentKind;
  final String? attachmentName;
  final Uint8List? previewBytes;
  final VoidCallback? onRemember;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = NovaColors.of(context);
    final kind = attachmentKind;
    final showImage = kind == AttachmentKind.image && previewBytes != null;

    return Align(
      alignment: Alignment.centerRight,
      // At most 78% of the chat column wide.
      child: FractionallySizedBox(
        widthFactor: 0.78,
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(NovaRadius.button),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 240,
                      maxWidth: 320,
                    ),
                    child: Image.memory(previewBytes!, fit: BoxFit.cover),
                  ),
                ),
              )
            else if (kind != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Chip(
                  avatar: Icon(
                    kind == AttachmentKind.pdf
                        ? NovaIcons.pdf
                        : NovaIcons.image,
                    size: NovaSize.icon,
                  ),
                  label: Text(
                    '${kind.label} attached'
                    '${attachmentName == null ? '' : ': $attachmentName'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            // Lime bubble, its bottom-right corner less round.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: NovaSpace.lg + 4,
                vertical: NovaSpace.md,
              ),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(NovaRadius.bubble),
                  topRight: Radius.circular(NovaRadius.bubble),
                  bottomLeft: Radius.circular(NovaRadius.bubble),
                  bottomRight: Radius.circular(NovaRadius.bubbleTail),
                ),
              ),
              child: SelectableText(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: c.onAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  _ActionButton(
                    tooltip: 'Edit message',
                    icon: NovaIcons.edit,
                    onPressed: onEdit!,
                  ),
                if (onRemember != null) _RememberButton(onPressed: onRemember!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelMessage extends StatelessWidget {
  const _ModelMessage({
    required this.text,
    required this.isStreaming,
    this.onRemember,
    this.onOpenArtifact,
    this.isSaved = false,
    this.onToggleSave,
    this.rating,
    this.onRate,
    this.onRegenerate,
  });
  final String text;
  final bool isStreaming;
  final Rating? rating;
  final ValueChanged<Rating>? onRate;
  final VoidCallback? onRegenerate;
  final bool isSaved;
  final VoidCallback? onToggleSave;
  final VoidCallback? onRemember;
  final ValueChanged<ArtifactBlock>? onOpenArtifact;

  @override
  Widget build(BuildContext context) {
    var segments = parseSegments(text);
    if (!isStreaming) {
      // A saved answer can end inside an artifact (Stop was pressed, or it
      // was cut to fit). Show what is there as a finished artifact.
      segments = [
        for (final s in segments)
          if (s case ArtifactSegment(:final artifact) when !artifact.isComplete)
            ArtifactSegment(
              ArtifactBlock(
                title: artifact.title,
                kind: artifact.kind,
                language: artifact.language,
                content: artifact.content,
              ),
            )
          else
            s,
      ];
    }
    final waiting = isStreaming && segments.isEmpty;
    final header = Row(
      children: [
        const NovaLogo(size: NovaSize.logoAnswer),
        const SizedBox(width: NovaSpace.sm + 2),
        Text(AppConstants.assistantName, style: NovaText.of(context).cardTitle),
      ],
    );

    // While Nova is thinking: three lime dots in a small card.
    if (waiting) {
      return Align(
        alignment: Alignment.centerLeft,
        child: NovaCard(
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpace.lg + 2,
            vertical: NovaSpace.md + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NovaLogo(size: NovaSize.logoAnswer),
              const SizedBox(width: NovaSpace.md),
              const TypingIndicator(),
            ],
          ),
        ),
      );
    }

    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: NovaSpace.md),
          // Text parts as safe Markdown; artifacts as cards. While the
          // answer streams, a small lime block shows where it's writing.
          for (var i = 0; i < segments.length; i++)
            switch (segments[i]) {
              TextSegment(:final text) => MarkdownMessage(
                text: text,
                showCursor: isStreaming && i == segments.length - 1,
              ),
              ArtifactSegment(:final artifact) => ArtifactCard(
                artifact: artifact,
                onOpen: onOpenArtifact == null
                    ? null
                    : () => onOpenArtifact!(artifact),
              ),
            },
          if (!isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: NovaSpace.sm),
              // Wrap: on narrow phones the buttons move to a second line
              // instead of overflowing.
              child: Transform.translate(
                // Lines the icons up with the text, not the buttons' edges.
                offset: const Offset(-NovaSpace.md, 0),
                child: Wrap(
                  children: [
                    _copyButton(context),
                    if (onRegenerate != null)
                      _ActionButton(
                        tooltip: 'Regenerate answer',
                        icon: NovaIcons.regenerate,
                        onPressed: onRegenerate!,
                      ),
                    if (onRate != null) ...[
                      _ActionButton(
                        tooltip: rating == Rating.up
                            ? 'Remove good response'
                            : 'Good response',
                        icon: NovaIcons.thumbUp,
                        selectedIcon: NovaIcons.thumbUp,
                        isSelected: rating == Rating.up,
                        onPressed: () => onRate!(Rating.up),
                      ),
                      _ActionButton(
                        tooltip: rating == Rating.down
                            ? 'Remove bad response'
                            : 'Bad response',
                        icon: NovaIcons.thumbDown,
                        selectedIcon: NovaIcons.thumbDown,
                        isSelected: rating == Rating.down,
                        onPressed: () => onRate!(Rating.down),
                      ),
                    ],
                    if (onToggleSave != null)
                      _SaveButton(isSaved: isSaved, onPressed: onToggleSave!),
                    if (onRemember != null)
                      _RememberButton(onPressed: onRemember!),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _copyButton(BuildContext context) => NovaIconButton(
    tooltip: 'Copy answer',
    icon: NovaIcons.copy,
    iconSize: NovaSize.iconSmall,
    onPressed: () async {
      // Without the artifact tags, so it reads normally when pasted.
      await Clipboard.setData(ClipboardData(text: plainText(text)));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
      );
    },
  );
}
