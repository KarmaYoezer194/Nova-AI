import 'package:cloud_firestore/cloud_firestore.dart';

/// Artifacts: long documents and code that Nova puts in a marked block, so
/// the app can show them in a side panel instead of in the chat.
///
/// Nova writes (see `artifactInstructions` in ai_service.dart):
///
/// ```text
/// <artifact title="Essay outline" kind="document">
/// ...Markdown...
/// </artifact>
/// ```
///
/// Safety (security rule 6): an artifact is only ever DISPLAYED, as safe
/// Markdown or as plain code text. Nothing in it is run, and HTML is never
/// rendered, whatever the block claims to be.
enum ArtifactKind {
  document,
  code;

  static ArtifactKind fromName(String? name) =>
      name == 'code' ? ArtifactKind.code : ArtifactKind.document;
}

/// One artifact block found in a message.
class ArtifactBlock {
  const ArtifactBlock({
    required this.title,
    required this.kind,
    required this.content,
    this.language,
    this.isComplete = true,
  });

  final String title;
  final ArtifactKind kind;
  final String content;

  /// For code, like "python". Null if not given or not a plain name.
  final String? language;

  /// False while the answer is still streaming and the block isn't closed.
  final bool isComplete;

  /// Identifies "the same artifact" across versions: its title, simplified.
  String get key => artifactKey(title);
}

/// Part of a model message: plain text, or an artifact.
sealed class MessageSegment {
  const MessageSegment();
}

class TextSegment extends MessageSegment {
  const TextSegment(this.text);
  final String text;
}

class ArtifactSegment extends MessageSegment {
  const ArtifactSegment(this.artifact);
  final ArtifactBlock artifact;
}

const int maxArtifactTitleLength = 120;

final _openTag = RegExp(r'<artifact\b([^>]*)>', caseSensitive: false);
final _closeTag = RegExp(r'</artifact\s*>', caseSensitive: false);
final _attribute = RegExp(r'(\w+)\s*=\s*"([^"]*)"');
final _plainLanguage = RegExp(r'^[a-z0-9+#.\-]{1,30}$');

/// Splits a model message into text and artifact parts.
///
/// An artifact whose closing tag hasn't arrived yet (still streaming) is
/// returned with `isComplete: false`. A half-written opening tag at the very
/// end (like "<artif") is hidden, so it doesn't flash on screen.
List<MessageSegment> parseSegments(String text) {
  final segments = <MessageSegment>[];
  var rest = text;
  while (true) {
    final open = _openTag.firstMatch(rest);
    if (open == null) break;
    _addText(segments, rest.substring(0, open.start));

    final attrs = {
      for (final m in _attribute.allMatches(open.group(1) ?? ''))
        m.group(1)!.toLowerCase(): m.group(2)!.trim(),
    };
    final afterOpen = rest.substring(open.end);
    final close = _closeTag.firstMatch(afterOpen);
    final body = close == null
        ? afterOpen
        : afterOpen.substring(0, close.start);
    final kind = ArtifactKind.fromName(attrs['kind']);
    final language = attrs['language']?.toLowerCase();

    segments.add(
      ArtifactSegment(
        ArtifactBlock(
          title: _cleanTitle(attrs['title']),
          kind: kind,
          language: language != null && _plainLanguage.hasMatch(language)
              ? language
              : null,
          content: _cleanBody(body, kind),
          isComplete: close != null,
        ),
      ),
    );
    if (close == null) return segments;
    rest = afterOpen.substring(close.end);
  }
  _addText(segments, _hidePartialTag(rest));
  return segments;
}

/// The artifacts in a message (complete ones only).
List<ArtifactBlock> artifactsIn(String text) => [
  for (final s in parseSegments(text))
    if (s is ArtifactSegment && s.artifact.isComplete) s.artifact,
];

/// The message as readable text, without the artifact tags (for Copy and
/// "Remember").
String plainText(String text) {
  final parts = <String>[];
  for (final s in parseSegments(text)) {
    switch (s) {
      case TextSegment(:final text):
        parts.add(text);
      case ArtifactSegment(:final artifact):
        parts.add('${artifact.title}\n\n${artifact.content}');
    }
  }
  return parts.join('\n\n').trim();
}

String artifactKey(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

void _addText(List<MessageSegment> segments, String text) {
  if (text.trim().isNotEmpty) segments.add(TextSegment(text.trim()));
}

String _cleanTitle(String? raw) {
  final title = (raw ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title.isEmpty) return 'Untitled';
  return title.length <= maxArtifactTitleLength
      ? title
      : title.substring(0, maxArtifactTitleLength);
}

String _cleanBody(String body, ArtifactKind kind) {
  var content = body.replaceAll(RegExp(r'^\s*\n'), '').trimRight();
  // Nova sometimes wraps code in ``` fences anyway; the panel shows raw code.
  if (kind == ArtifactKind.code) {
    final fenced = RegExp(r'^```[^\n]*\n([\s\S]*?)\n?```$').firstMatch(content);
    if (fenced != null) content = fenced.group(1)!;
  }
  return content;
}

String _hidePartialTag(String text) {
  final match = RegExp(r'<[a-zA-Z]*$').firstMatch(text);
  if (match == null) return text;
  final tail = match.group(0)!.toLowerCase();
  return '<artifact'.startsWith(tail) ? text.substring(0, match.start) : text;
}

/// One saved version of an artifact.
///
/// Firestore path: users/{uid}/conversations/{cid}/artifacts/{id}
/// Each time Nova writes an artifact with the same title in a chat, a new
/// version is saved, so earlier versions can still be viewed.
class ArtifactVersion {
  const ArtifactVersion({
    required this.id,
    required this.key,
    required this.title,
    required this.kind,
    required this.content,
    required this.version,
    this.language,
    this.messageId,
    this.createdAt,
  });

  final String id;
  final String key;
  final String title;
  final ArtifactKind kind;
  final String content;
  final int version;
  final String? language;
  final String? messageId;
  final DateTime? createdAt;

  ArtifactBlock toBlock() => ArtifactBlock(
    title: title,
    kind: kind,
    content: content,
    language: language,
  );

  factory ArtifactVersion.fromMap(String id, Map<String, dynamic> data) {
    String? str(String k) => data[k] is String ? data[k] as String : null;
    final created = data['createdAt'];
    return ArtifactVersion(
      id: id,
      key: str('key') ?? '',
      title: str('title') ?? 'Untitled',
      kind: ArtifactKind.fromName(str('kind')),
      content: str('content') ?? '',
      version: data['version'] is int ? data['version'] as int : 1,
      language: str('language'),
      messageId: str('messageId'),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
