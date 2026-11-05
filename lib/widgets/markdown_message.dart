import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import '../app/nova_colors.dart';
import '../app/nova_icons.dart';
import '../app/nova_tokens.dart';
import '../app/nova_typography.dart';

/// Shows Nova's answer as formatted Markdown, safely (security rule 6).
///
/// - Headings, lists, bold, tables and code blocks are drawn as native
///   Flutter widgets. Nothing is run, and HTML is never rendered.
/// - Code blocks get a Copy button.
/// - Images are NOT loaded. A model-written image link could quietly send
///   data to someone else's server just by being displayed, so we show its
///   description as text instead.
/// - Links open only when tapped, after the user sees the full address.
class MarkdownMessage extends StatelessWidget {
  const MarkdownMessage({
    super.key,
    required this.text,
    this.showCursor = false,
  });

  final String text;

  /// While the answer streams: a small lime block after the last word.
  final bool showCursor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = NovaColors.of(context);
    final base = NovaText.of(context).body;

    return MarkdownBody(
      data: showCursor ? withCursor(text) : _noMarker(text),
      selectable: !showCursor,
      // GitHub-style tables, strikethrough and task lists.
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [_CursorSyntax()],
      onTapLink: (text, href, title) => _confirmAndOpen(context, href),
      imageBuilder: (uri, title, alt) => Text(
        '[image${alt == null || alt.isEmpty ? '' : ': $alt'}]',
        style: base.copyWith(color: c.textMuted),
      ),
      builders: {'pre': _CodeBlockBuilder(), 'cursor': _CursorBuilder()},
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: base,
        listBullet: base,
        h1: theme.textTheme.headlineSmall,
        h2: theme.textTheme.titleLarge,
        h3: theme.textTheme.titleMedium,
        // Inline code: DM Mono on the raised card colour.
        code: NovaText.of(context).code.copyWith(backgroundColor: c.cardRaised),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: theme.colorScheme.outline, width: 3),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
      ),
    );
  }
}

/// Opens a link only after the user confirms the full address.
/// Only web links (http/https) are allowed.
Future<void> _confirmAndOpen(BuildContext context, String? href) async {
  final uri = href == null ? null : Uri.tryParse(href);
  final isWebLink =
      uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  if (!isWebLink) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This link can\'t be opened.')),
    );
    return;
  }

  final open = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Open this link?'),
      content: SelectableText(uri.toString()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Open'),
        ),
      ],
    ),
  );
  if (open == true) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Marks where the streaming cursor goes: U+E000, a private-use character
/// (never real text). It's removed from Nova's own text first, so the model
/// can't place cursors itself.
final String cursorMarker = String.fromCharCode(0xE000);
String get _cursorMarker => cursorMarker;

String _noMarker(String text) => text.replaceAll(_cursorMarker, '');

/// [text] with the cursor marker after the last word. Inside an unfinished
/// code block it would show as a character, so it's left out there.
String withCursor(String text) {
  final clean = _noMarker(text).trimRight();
  final openFence = '```'.allMatches(clean).length.isOdd;
  return openFence ? clean : '$clean $_cursorMarker';
}

class _CursorSyntax extends md.InlineSyntax {
  _CursorSyntax() : super(_cursorMarker);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.empty('cursor'));
    return true;
  }
}

/// The lime block cursor (decoration only: screen readers skip it).
class _CursorBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // Returned as text (a WidgetSpan), so the Markdown renderer joins it to
    // the paragraph's last line instead of putting it on its own line.
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ExcludeSemantics(
              child: Container(
                key: const ValueKey('streaming-cursor'),
                width: 8,
                height: 16,
                decoration: BoxDecoration(
                  color: NovaColors.of(context).accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws ``` code blocks ``` in a box with the language and a Copy button.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // The language comes from ```dart → <code class="language-dart">.
    final codeElement = element.children?.whereType<md.Element>().firstOrNull;
    final className = codeElement?.attributes['class'] ?? '';
    final language = className.startsWith('language-')
        ? className.substring(9)
        : '';
    final code = element.textContent.trimRight();

    return _CodeBlock(code: code, language: language);
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, required this.language});

  final String code;
  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: NovaColors.of(context).cardRaised,
        borderRadius: BorderRadius.circular(NovaRadius.row),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 0),
            child: Row(
              children: [
                Text(
                  language.isEmpty ? 'code' : language,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(NovaIcons.copy, size: NovaSize.iconSmall),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            // Shown as text only: never run (security rule 6).
            child: SelectableText(code, style: NovaText.of(context).code),
          ),
        ],
      ),
    );
  }
}
