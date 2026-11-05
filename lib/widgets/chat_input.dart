import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/constants.dart';
import '../models/attachment.dart';
import '../services/links.dart';
import '../app/nova_colors.dart';
import '../app/nova_icons.dart';
import '../app/nova_tokens.dart';
import '../app/nova_typography.dart';
import 'nova/nova_icon_button.dart';

/// Called when the user sends. [attachment] is null if no file is attached.
typedef SendCallback = void Function(String text, Attachment? attachment);

/// The big rounded message box pinned at the bottom of the chat.
///
/// - Grows with the text (up to 8 lines, then scrolls).
/// - Enter sends; Shift+Enter adds a new line (on a computer keyboard).
/// - Attach button for one photo or PDF (checked before it is accepted).
/// - While an answer is streaming, Send becomes Stop and sending is blocked
///   (security rule 4).
class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.onSend,
    required this.isBusy,
    this.onStop,
    this.editingText,
    this.onCancelEdit,
    this.large = false,
  });

  /// The big two-line box on the new-chat screen (buttons underneath),
  /// instead of the round one-line pill in a chat.
  final bool large;

  /// Edit (UI round 2): when this changes to a non-null value, the box is
  /// filled with it and an "Editing message" bar with Cancel is shown.
  final String? editingText;
  final VoidCallback? onCancelEdit;

  final SendCallback onSend;

  /// True while Nova is answering. Sending is blocked until it finishes.
  final bool isBusy;

  /// Called when the user taps Stop while Nova is answering.
  final VoidCallback? onStop;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _handleKey);
  Attachment? _attachment;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    // Rebuild when the text changes, to enable/disable the Send button.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(ChatInput old) {
    super.didUpdateWidget(old);
    final text = widget.editingText;
    if (text != null && text != old.editingText) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      _focusNode.requestFocus();
    } else if (text == null && old.editingText != null) {
      _controller.clear(); // Edit cancelled.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !widget.isBusy &&
      (_controller.text.trim().isNotEmpty || _attachment != null);

  void _submit() {
    if (!_canSend) return;
    final text = _controller.text.trim();
    final attachment = _attachment;
    _controller.clear();
    setState(() => _attachment = null);
    widget.onSend(text, attachment);
    _focusNode.requestFocus();
  }

  Future<void> _pickFile() async {
    if (_picking || widget.isBusy) return;
    setState(() => _picking = true);
    try {
      // The extension filter only helps the file chooser; the real type
      // check (by file content) happens in Attachment.fromPickedFile.
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (file == null) return; // Cancelled.

      // Check the size BEFORE reading the whole file into memory.
      final size = file.lengthSync() ?? await file.length();
      if (size != null && size > AppConstants.maxAttachmentBytes) {
        throw AttachmentException(
          'That file is too big. The limit is ${formatFileSize(AppConstants.maxAttachmentBytes)}.',
        );
      }
      final bytes = await file.readAsBytes();
      final attachment = Attachment.fromPickedFile(
        name: file.name,
        bytes: bytes,
      );
      if (mounted) setState(() => _attachment = attachment);
    } on AttachmentException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      if (kDebugMode) debugPrint('File pick error: $e');
      _showMessage('Couldn\'t open that file. Please try another one.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    // While typing with an input method (for example Thai or Japanese),
    // Enter confirms the word instead of sending.
    final isComposing = _controller.value.composing.isValid;
    if (event is KeyDownEvent &&
        isEnter &&
        !isComposing &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = NovaColors.of(context);
    final length = _controller.text.length;
    final nearLimit = length > AppConstants.maxUserMessageLength - 500;
    // Set expectations before sending: Google opens the page, and only
    // public pages can be read.
    final hasLink = findLinks(_controller.text).isNotEmpty;

    final attachButton = NovaIconButton(
      tooltip:
          'Attach image or PDF\nImages and PDFs, up to '
          '${formatFileSize(AppConstants.maxAttachmentBytes)}',
      icon: NovaIcons.attach,
      kind: NovaIconButtonKind.strong,
      onPressed: widget.isBusy || _picking ? null : _pickFile,
    );
    // Lime Send; grey while there's nothing to send. Stop while answering.
    final sendButton = widget.isBusy
        ? NovaIconButton(
            tooltip: 'Stop answering',
            icon: NovaIcons.stop,
            kind: NovaIconButtonKind.accent,
            iconSize: NovaSize.iconSmall,
            onPressed: widget.onStop,
          )
        : NovaIconButton(
            tooltip: 'Send message',
            icon: NovaIcons.send,
            kind: NovaIconButtonKind.accent,
            onPressed: _canSend ? _submit : null,
          );
    final counter = nearLimit
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: NovaSpace.sm),
            child: Text(
              '$length / ${AppConstants.maxUserMessageLength}',
              style: NovaText.of(context).caption,
            ),
          )
        : null;
    final field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: true,
      // The big new-chat box starts two lines tall.
      minLines: widget.large ? 2 : 1,
      // Grows with the text, then scrolls inside.
      maxLines: AppConstants.maxInputLines,
      // App-side cap (security rule 4).
      maxLength: AppConstants.maxUserMessageLength,
      textInputAction: TextInputAction.newline,
      keyboardType: TextInputType.multiline,
      style: theme.textTheme.bodyMedium,
      decoration: const InputDecoration(
        hintText: 'Ask ${AppConstants.assistantName} anything…',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: NovaSpace.sm,
          vertical: NovaSpace.md,
        ),
        counterText: '', // We show our own counter.
      ),
    );

    // Chat: a fully round pill, everything in one row. New chat: a big
    // card, the text on top and the buttons underneath.
    final buttons = widget.large
        ? Row(children: [attachButton, ?counter, const Spacer(), sendButton])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              attachButton,
              const SizedBox(width: NovaSpace.xs),
              Expanded(child: field),
              ?counter,
              const SizedBox(width: NovaSpace.xs),
              sendButton,
            ],
          );

    return Container(
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(
          widget.large ? NovaRadius.composerLarge : NovaRadius.composer,
        ),
        border: Border.all(color: c.fieldBorder),
      ),
      padding: widget.large
          ? const EdgeInsets.fromLTRB(
              NovaSpace.md,
              NovaSpace.sm,
              NovaSpace.md,
              NovaSpace.md,
            )
          : const EdgeInsets.all(NovaSpace.xs + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.editingText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
              child: Row(
                children: [
                  Icon(
                    NovaIcons.edit,
                    size: NovaSize.iconSmall,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Editing message',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onCancelEdit,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          if (_attachment != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: _AttachmentPreview(
                attachment: _attachment!,
                onRemove: () => setState(() => _attachment = null),
              ),
            ),
          if (widget.large) field,
          if (hasLink)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NovaSpace.md,
                NovaSpace.xs,
                NovaSpace.md,
                NovaSpace.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    NovaIcons.link,
                    size: NovaSize.iconSmall,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      linkHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          buttons,
        ],
      ),
    );
  }
}

/// Shown above the buttons while the typed text contains a link.
const String linkHint =
    '${AppConstants.assistantName} will read this link. Only public pages work.';

/// The picked file shown above the text, with a button to remove it.
class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.attachment, required this.onRemove});

  final Attachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImage = attachment.kind == AttachmentKind.image;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(NovaRadius.row),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(NovaRadius.sm),
            child: SizedBox.square(
              dimension: 48,
              child: isImage
                  ? Image.memory(attachment.bytes, fit: BoxFit.cover)
                  : ColoredBox(
                      color: theme.colorScheme.errorContainer,
                      child: Icon(
                        NovaIcons.pdf,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '${attachment.kind.label} · ${formatFileSize(attachment.sizeInBytes)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove attachment',
            onPressed: onRemove,
            icon: const Icon(NovaIcons.close),
          ),
        ],
      ),
    );
  }
}
