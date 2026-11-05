import 'package:firebase_ai/firebase_ai.dart';

import '../models/chat_message.dart';

/// Reading links the user pastes (URL context tool).
///
/// How it works: when a message contains web links, we turn on Gemini's URL
/// context tool for that message. GOOGLE fetches the pages (the app never
/// downloads them) and gives their text to the model.
///
/// Security: page content is data, not instructions (rule 5). Only public
/// pages can be read; paywalled or sign-in pages fail, and Nova says so.

/// Most links read in one message (the API allows up to 20).
const int maxLinksPerMessage = 20;

final _link = RegExp(r'''https?://[^\s<>"'`]+''', caseSensitive: false);

/// The http(s) links in [text], in order, without duplicates and without
/// trailing punctuation like "." or ")".
List<Uri> findLinks(String text) {
  final found = <Uri>[];
  for (final m in _link.allMatches(text)) {
    var raw = m.group(0)!;
    while (raw.isNotEmpty && '.,;:!?)]}'.contains(raw[raw.length - 1])) {
      raw = raw.substring(0, raw.length - 1);
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) continue;
    if (uri.scheme != 'http' && uri.scheme != 'https') continue;
    if (!found.contains(uri)) found.add(uri);
  }
  return found;
}

/// What happened when Google tried to read one link.
enum LinkStatus { read, paywall, unsafe, failed }

class LinkResult {
  const LinkResult(this.url, this.status);
  final Uri? url;
  final LinkStatus status;
}

/// The link results in one piece of a streamed answer (empty if none).
///
/// firebase_ai doesn't export its URL-result types, so we map them by
/// name ("success", "paywall", "unsafe", ...) into our own [LinkResult].
List<LinkResult> linkResultsIn(GenerateContentResponse chunk) {
  final metadata = chunk.candidates.firstOrNull?.urlContextMetadata;
  if (metadata == null) return const [];
  return [
    for (final m in metadata.urlMetadata)
      LinkResult(m.retrievedUrl, switch (m.urlRetrievalStatus.name) {
        'success' => LinkStatus.read,
        'paywall' => LinkStatus.paywall,
        'unsafe' => LinkStatus.unsafe,
        _ => LinkStatus.failed,
      }),
  ];
}

// ---------- News mode ----------
//
// Free alternative to web search (search isn't available on our free
// tier): Nova reads Wikipedia's "Current events" page, which volunteers
// update every day. Its license (CC BY-SA) allows reuse with credit, so
// every news answer ends with a credited source link.

/// The page Nova reads in News mode.
final Uri newsSourceUrl = Uri.parse(
  'https://en.wikipedia.org/wiki/Portal:Current_events',
);

// Words and phrases that mean "what's going on in the world right now".
// Simple on purpose: it runs on the phone, costs nothing, and a false alarm
// is harmless (Nova is told to ignore the page if it isn't relevant).
final _newsQuestion = RegExp(
  r"\b(news|headlines?|current events?|breaking|"
  r"what'?s (going on|happening)|what is (going on|happening)|"
  r"happening (now|today|right now|in the world|around the world)|"
  r"what happened (today|yesterday|this week|recently)|"
  r"(today'?s|this week'?s|recent|latest) (events|stories|updates|developments)|"
  r"in the world (today|right now|now))\b",
  caseSensitive: false,
);

/// True if [text] asks about current news, or follows up on a news answer
/// (the last message in [history] is a News-mode answer).
bool isNewsQuestion(String text, {List<ChatMessage> history = const []}) {
  if (_newsQuestion.hasMatch(text)) return true;
  final last = history.isEmpty ? null : history.last;
  return last != null && !last.isUser && last.text.contains('$newsSourceUrl');
}

/// The text sent to the model in News mode: the question plus the page to
/// read. Only the user's own text is saved in the chat.
String withNewsSource(String userText) =>
    '$userText\n\n(Read this page for the latest news: $newsSourceUrl)';

bool isNewsSource(Uri? url) =>
    url != null &&
    url.host.endsWith('wikipedia.org') &&
    url.path.contains('Current_events');

/// Added under a News-mode answer: the credited source if the page was
/// read, or a warning that the answer may not be current.
String newsSourceNote(List<LinkResult> results) {
  final read = results.any(
    (r) =>
        r.status == LinkStatus.read && (isNewsSource(r.url) || r.url == null),
  );
  if (read) {
    return '\n\n---\n**Source:** [Wikipedia — Current events]'
        '($newsSourceUrl) (CC BY-SA). News there is added by volunteers '
        'and may be a few hours behind.';
  }
  return '\n\n---\n*I couldn\'t load today\'s news page this time, so this '
      'answer may not be current. Please try again in a moment.*';
}

/// A note added under the answer for pages that couldn't be read, asking
/// the user to paste the text. Null if every page was read (or none were
/// tried).
String? unreadLinksNote(List<LinkResult> results) {
  final failed = [
    for (final r in results)
      if (r.status != LinkStatus.read) r,
  ];
  if (failed.isEmpty) return null;

  String reason(LinkStatus s) => switch (s) {
    LinkStatus.paywall => 'it needs a subscription or sign-in',
    LinkStatus.unsafe => 'it was flagged as unsafe',
    _ => 'it couldn\'t be opened',
  };

  final lines = [
    for (final r in failed) '- ${r.url ?? 'A link'}: ${reason(r.status)}',
  ];
  return '\n\n---\n'
      '**I couldn\'t read ${failed.length == 1 ? 'this page' : 'these pages'}:**\n'
      '${lines.join('\n')}\n\n'
      'If you\'d like, copy the text from the page and paste it here.';
}
