import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/constants.dart';
import '../models/artifact.dart';
import '../models/attachment.dart';
import '../models/chat_message.dart';
import '../models/memory.dart';
import '../models/project.dart';
import '../services/ai_service.dart';
import '../services/chat_repository.dart';
import '../services/feedback_repository.dart';
import '../services/memory_repository.dart';
import '../services/links.dart';
import '../services/tools.dart';
import '../widgets/artifact_panel.dart';
import '../widgets/chat_input.dart';
import '../widgets/remember_dialog.dart';
import '../widgets/empty_chat.dart';
import '../widgets/message_bubble.dart';
import '../app/nova_icons.dart';
import '../app/nova_tokens.dart';
import '../app/nova_typography.dart';

/// The chat column: messages, the streaming answer, and the input box.
///
/// Flow when the user sends a message:
/// 1. (New chat only) create the conversation, titled from the message.
/// 2. Save the user's message.
/// 3. Stream Nova's answer and show it word by word (Stop ends it early).
/// 4. Save the answer ONCE, after streaming finishes or is stopped.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.uid,
    required this.services,
    required this.initialConversationId,
    required this.onConversationCreated,
    this.projectId,
    this.projectName,
    this.onOpenProject,
    this.initialMessageId,
    this.chatTitle,
    this.displayName,
    this.greetingName,
  });

  /// The name the user set on their account, if any. Only its first word is
  /// shared with Nova; the email never is.
  final String? displayName;

  /// For the new-chat greeting ("Good evening, John"). Shown on screen
  /// only, never sent to Nova.
  final String? greetingName;

  /// Opened from Saved: scroll to this message and highlight it briefly.
  final String? initialMessageId;

  /// The chat's current title (stored with saved answers).
  final String? chatTitle;

  /// The project this chat belongs to (or will belong to, for a new chat).
  final String? projectId;

  /// Shown at the top of the chat. Tapping it calls [onOpenProject].
  final String? projectName;
  final VoidCallback? onOpenProject;

  final String uid;
  final AppServices services;

  /// Null for a brand-new chat.
  final String? initialConversationId;

  /// Tells the parent (and so the sidebar) about a newly created chat.
  final ValueChanged<String> onConversationCreated;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();

  String? _conversationId;
  StreamSubscription<List<ChatMessage>>? _messagesSub;

  /// Latest saved messages from Firestore (newest 50, oldest first).
  List<ChatMessage> _messages = const [];
  bool _loaded = false;

  bool _isStreaming = false;
  String _streamingText = '';

  /// What Nova is doing with a tool right now (like "Searching your
  /// chats"), shown above the typing dots. Null when not using a tool.
  String? _toolStatus;

  /// The answer being streamed, so Stop can cancel it.
  StreamSubscription<String>? _answerSub;

  /// Completes when the answer finishes, fails or is stopped.
  /// Value: an error message to show, or null.
  Completer<String?>? _answerDone;

  /// The message being sent, shown right away until its saved copy arrives
  /// from Firestore (see [_pendingAlreadySaved]).
  String? _pendingUserText;
  Attachment? _pendingAttachment;

  /// Photos sent in this session, by message id, so they can be shown in
  /// the chat. Memory only: files are never stored, so after leaving the
  /// chat only the "photo attached" note remains.
  final Map<String, Uint8List> _sessionPreviews = {};

  /// Ids of the messages that existed before the current send.
  Set<String> _idsBeforeSend = const {};
  String? _error;

  /// True when the user has scrolled up, away from the newest message.
  bool _showJumpToLatest = false;

  /// Ids of this chat's saved answers (filled bookmarks). Updates live.
  Set<String> _savedIds = const {};
  StreamSubscription<Set<String>>? _savedSub;

  /// The message to scroll to (opened from Saved), until it is reached.
  String? _targetMessageId;
  final _targetKey = GlobalKey();

  /// The message highlighted for a moment after scrolling to it.
  String? _highlightId;

  /// Thumbs up / down for this chat's answers, by message id. Updates live.
  Map<String, Rating> _ratings = const {};
  StreamSubscription<Map<String, Rating>>? _ratingsSub;

  /// The message being edited (Edit button), or null.
  ChatMessage? _editing;

  /// The title this screen gave a new chat (until the parent's copy updates).
  String? _localTitle;

  @override
  void initState() {
    super.initState();
    _targetMessageId = widget.initialMessageId;
    _scrollController.addListener(_onScroll);
    final id = widget.initialConversationId;
    if (id == null) {
      _loaded = true; // Nothing to load for a new chat.
    } else {
      _listenTo(id);
    }
  }

  @override
  void dispose() {
    // Stops listening to Firestore. If an answer is still streaming, it
    // keeps going in the background and is still saved when it finishes.
    _messagesSub?.cancel();
    _savedSub?.cancel();
    _ratingsSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // The list is reversed, so offset 0 is the newest message (the bottom).
  void _onScroll() {
    final away = _scrollController.offset > 300;
    if (away != _showJumpToLatest) {
      setState(() => _showJumpToLatest = away);
    }
  }

  void _jumpToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _listenTo(String conversationId) {
    _conversationId = conversationId;
    _listenToSaved(conversationId);
    _messagesSub?.cancel();
    _messagesSub = widget.services.chat
        .watchMessages(widget.uid, conversationId)
        .listen(
          (messages) {
            if (!mounted) return;
            setState(() {
              _messages = messages;
              _loaded = true;
            });
            final target = _targetMessageId;
            if (target != null) {
              _targetMessageId = null;
              if (messages.any((m) => m.id == target)) {
                _scrollToMessage(target);
              } else {
                // Older than the messages we load: open at the newest instead.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('That answer is further back in this chat.'),
                  ),
                );
              }
            }
          },
          onError: (Object error) {
            if (kDebugMode) debugPrint('Messages error: $error');
            if (!mounted) return;
            setState(() {
              _loaded = true;
              _error = 'Couldn\'t load this chat. Please try again.';
            });
          },
        );
  }

  void _listenToSaved(String conversationId) {
    _ratingsSub?.cancel();
    _ratingsSub = widget.services.feedback
        .watchIn(widget.uid, conversationId)
        .listen(
          (ratings) {
            if (mounted) setState(() => _ratings = ratings);
          },
          onError: (Object error) {
            if (kDebugMode) debugPrint('Feedback load error: $error');
          },
        );
    _savedSub?.cancel();
    _savedSub = widget.services.saved
        .watchSavedIn(widget.uid, conversationId)
        .listen(
          (ids) {
            if (mounted) setState(() => _savedIds = ids);
          },
          onError: (Object error) {
            if (kDebugMode) debugPrint('Saved error: $error');
          },
        );
  }

  /// Scrolls the (lazy, reversed) list until the message is built, then
  /// brings it into view and highlights it for a moment.
  Future<void> _scrollToMessage(String id) async {
    setState(() => _highlightId = id);
    for (var i = 0; i < 60; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scrollController.hasClients) return;
      final target = _targetKey.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.2,
          duration: const Duration(milliseconds: 300),
        );
        break;
      }
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent) break;
      _scrollController.jumpTo(
        (pos.pixels + pos.viewportDimension * 0.8).clamp(
          0,
          pos.maxScrollExtent,
        ),
      );
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted && _highlightId == id) setState(() => _highlightId = null);
  }

  /// Bookmark under an answer: saves it to (or removes it from) Saved.
  Future<void> _toggleSave(ChatMessage m) async {
    final conversationId = _conversationId;
    if (conversationId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final wasSaved = _savedIds.contains(m.id);
    // Show the change at once; the live listener confirms it.
    setState(
      () => _savedIds = wasSaved
          ? ({..._savedIds}..remove(m.id))
          : {..._savedIds, m.id},
    );
    try {
      if (wasSaved) {
        await widget.services.saved.remove(widget.uid, conversationId, m.id);
      } else {
        await widget.services.saved.save(
          uid: widget.uid,
          conversationId: conversationId,
          messageId: m.id,
          chatTitle: widget.chatTitle ?? _localTitle ?? 'Chat',
          answer: m.text,
        );
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(wasSaved ? 'Removed from Saved' : 'Saved'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Save toggle error: $error');
      _update(
        () => _savedIds = wasSaved
            ? {..._savedIds, m.id}
            : ({..._savedIds}..remove(m.id)),
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t update Saved. Check your connection.'),
        ),
      );
    }
  }

  /// Regenerate (latest answer only): deletes the answer and asks the
  /// same question again.
  Future<void> _regenerate() async {
    final conversationId = _conversationId;
    if (conversationId == null || _isStreaming || _messages.length < 2) return;
    final answer = _messages.last;
    final question = _messages[_messages.length - 2];
    if (answer.isUser || !question.isUser) return;
    final history = _messages.sublist(0, _messages.length - 2);

    _update(() {
      _isStreaming = true;
      _streamingText = '';
      _error = null;
      _editing = null;
    });
    _jumpToLatest();
    final personalizationFuture = _loadPersonalization();
    final projectFuture = _loadProject();
    try {
      await widget.services.chat.deleteMessages(widget.uid, conversationId, [
        answer.id,
      ]);
    } catch (error) {
      if (kDebugMode) debugPrint('Regenerate error: $error');
      _update(() {
        _isStreaming = false;
        _error = 'Couldn\'t regenerate. Check your connection.';
      });
      return;
    }
    // A file sent with the question is never stored, so it can't be sent
    // again: Nova is told it is no longer available.
    final text = question.hasAttachment
        ? '${pastAttachmentNote(question)}\n\n${question.text}'
        : question.text;
    await _answer(
      conversationId: conversationId,
      history: history,
      text: text,
      personalizationFuture: personalizationFuture,
      projectFuture: projectFuture,
    );
  }

  /// Edit (the user's latest message only): puts its text in the input
  /// box. Sending replaces it and the answer after it.
  void _startEdit(ChatMessage m) => setState(() => _editing = m);

  void _cancelEdit() => setState(() => _editing = null);

  /// Thumbs up / down: tapping the same one again removes it.
  Future<void> _rate(ChatMessage m, Rating rating) async {
    final conversationId = _conversationId;
    if (conversationId == null) return;
    final old = _ratings[m.id];
    final next = old == rating ? null : rating;
    setState(() {
      _ratings = {..._ratings};
      if (next == null) {
        _ratings.remove(m.id);
      } else {
        _ratings[m.id] = next;
      }
    });
    final feedback = widget.services.feedback;
    try {
      if (next == null) {
        await feedback.remove(widget.uid, conversationId, m.id);
      } else {
        await feedback.rate(
          uid: widget.uid,
          conversationId: conversationId,
          messageId: m.id,
          rating: next,
          replacing: old != null,
        );
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Feedback error: $error');
      _update(() {
        _ratings = {..._ratings};
        if (old == null) {
          _ratings.remove(m.id);
        } else {
          _ratings[m.id] = old;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t save your feedback. Try again.'),
          ),
        );
      }
    }
  }

  /// After the first answer in a new chat: ask Nova for a short title.
  /// If it fails, the chat keeps its first-message title (no error shown).
  Future<void> _nameChat(
    String conversationId,
    String question,
    String answer,
  ) async {
    final title = await widget.services.ai.suggestTitle(question, answer);
    if (title == null) return;
    try {
      await widget.services.chat.renameConversation(
        widget.uid,
        conversationId,
        title,
      );
      _localTitle = title;
    } catch (error) {
      if (kDebugMode) debugPrint('Rename error: $error');
    }
  }

  void _update(VoidCallback change) {
    if (mounted) setState(change);
  }

  /// Stop button: ends the answer early. What arrived so far is kept.
  void _stop() {
    _answerSub?.cancel();
    final done = _answerDone;
    if (done != null && !done.isCompleted) done.complete(null);
  }

  Future<void> _send(String raw, [Attachment? attachment]) async {
    final typed = raw.trim();
    if ((typed.isEmpty && attachment == null) || _isStreaming) return;
    // A file with no question still needs some text.
    final text = typed.isEmpty ? AppConstants.defaultAttachmentQuestion : typed;

    final repo = widget.services.chat;
    final uid = widget.uid;
    // Edit: the edited message and the answer after it are replaced.
    final editing = _editing;
    final editIndex = editing == null
        ? -1
        : _messages.indexWhere((m) => m.id == editing.id);
    final replaced = editIndex < 0
        ? const <String>[]
        : [for (final m in _messages.sublist(editIndex)) m.id];
    // History = messages BEFORE this one (the new message is sent separately).
    final history = List<ChatMessage>.of(
      editIndex < 0 ? _messages : _messages.sublist(0, editIndex),
    );

    _update(() {
      _isStreaming = true;
      _streamingText = '';
      _error = null;
      _editing = null;
      _pendingUserText = text;
      _pendingAttachment = attachment;
      _idsBeforeSend = {for (final m in _messages) m.id};
    });
    _jumpToLatest();

    // Started now so it runs at the same time as saving (usually instant).
    final personalizationFuture = _loadPersonalization();
    final projectFuture = _loadProject();

    // Steps 1 and 2: make sure the chat exists, then save the user's message
    // (with a note about the file, never the file itself).
    String conversationId;
    final isNewChat = _conversationId == null;
    try {
      final existing = _conversationId;
      if (existing == null) {
        final title = typed.isEmpty && attachment != null
            ? '${attachment.kind.label}: ${attachment.name}'
            : text;
        _localTitle = cleanTitle(title);
        conversationId = await repo.createConversation(
          uid,
          title: title,
          projectId: widget.projectId,
        );
        if (mounted) _listenTo(conversationId);
        widget.onConversationCreated(conversationId);
      } else {
        conversationId = existing;
      }
      if (replaced.isNotEmpty) {
        await repo.deleteMessages(uid, conversationId, replaced);
      }
      final messageId = await repo.addMessage(
        uid: uid,
        conversationId: conversationId,
        role: MessageRole.user,
        text: text,
        attachmentKind: attachment?.kind,
        attachmentName: attachment?.name,
      );
      if (attachment != null && attachment.kind == AttachmentKind.image) {
        _update(() => _sessionPreviews[messageId] = attachment.bytes);
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Send error: $error');
      _update(() {
        _isStreaming = false;
        _pendingUserText = null;
        _pendingAttachment = null;
        _error =
            'Couldn\'t send your message. '
            'Check your connection and try again.';
      });
      return;
    }
    _update(() {
      _pendingUserText = null;
      _pendingAttachment = null;
    });

    await _answer(
      conversationId: conversationId,
      history: history,
      text: text,
      attachment: attachment,
      personalizationFuture: personalizationFuture,
      projectFuture: projectFuture,
      isNewChat: isNewChat,
    );
  }

  /// Steps 3 to 5: streams Nova's answer to [text] and saves it. Used by
  /// Send, and by Regenerate (which asks the same question again).
  Future<void> _answer({
    required String conversationId,
    required List<ChatMessage> history,
    required String text,
    Attachment? attachment,
    required Future<Personalization> personalizationFuture,
    required Future<Project?> projectFuture,
    bool isNewChat = false,
  }) async {
    final repo = widget.services.chat;
    final uid = widget.uid;

    // Step 3: stream the answer (the file goes with this request only).
    // Instructions and memories are kept up to date live, so edits in
    // Settings apply to the very next message.
    // The first name comes only from a display name the user set.
    final personalization = (await personalizationFuture).withDisplayName(
      widget.displayName,
    );
    final project = await projectFuture;
    // Read-only tools, bound to THIS user (the model can't pick whose data
    // they read). The current chat is left out of the search.
    final tools = NovaTools(
      searchChats: (query) =>
          repo.searchChats(uid, query, excludeConversationId: conversationId),
      onUse: (label) => _update(() => _toolStatus = label),
    );
    // A message with links is answered by reading them (Google fetches the
    // pages); show that while Nova waits for them.
    // News questions (or follow-ups to a news answer) are answered from
    // today's news page, automatically.
    final news = isNewsQuestion(text, history: history);
    final linkCount = findLinks(text).length;
    if (news) {
      _update(() => _toolStatus = 'Checking today\'s news');
    } else if (linkCount > 0) {
      _update(
        () => _toolStatus = linkCount == 1
            ? 'Reading the link'
            : 'Reading the links',
      );
    }
    final answer = StringBuffer();
    // Debug builds only: how long Nova takes (first words, whole answer).
    final timer = Stopwatch()..start();
    Duration? firstPiece;
    final done = Completer<String?>();
    _answerDone = done;
    _answerSub = widget.services.ai
        .streamReply(
          history: history,
          userText: text,
          attachment: attachment,
          personalization: personalization,
          project: project,
          tools: tools,
          news: news,
        )
        .listen(
          (piece) {
            firstPiece ??= timer.elapsed;
            answer.write(piece);
            _update(() {
              _streamingText = answer.toString();
              _toolStatus = null;
            });
          },
          onError: (Object error) {
            if (done.isCompleted) return;
            done.complete(
              error is AiFailure
                  ? error.message
                  : 'Something went wrong. Please try again.',
            );
          },
          onDone: () {
            if (!done.isCompleted) done.complete(null);
          },
          cancelOnError: true,
        );
    final errorMessage = await done.future;
    if (kDebugMode) {
      debugPrint(
        'Answer timing: first words after '
        '${firstPiece?.inMilliseconds ?? '-'} ms, '
        'finished after ${timer.elapsedMilliseconds} ms',
      );
    }
    _answerSub = null;
    _answerDone = null;

    // Step 4: save what we have, once (the full answer, or the part before
    // Stop or an error).
    final finalText = answer.toString().trim();
    _update(() {
      _isStreaming = false;
      _streamingText = '';
      _toolStatus = null;
      _error = errorMessage;
    });
    if (finalText.isEmpty) return;

    final String messageId;
    try {
      // The saved copy shows up through the Firestore listener at once.
      messageId = await repo.addMessage(
        uid: uid,
        conversationId: conversationId,
        role: MessageRole.model,
        text: finalText,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Save answer error: $error');
      _update(
        () => _error =
            'Couldn\'t save ${AppConstants.assistantName}\'s answer. '
            'Check your connection.',
      );
      return;
    }

    // First answer in a new chat: give the chat a meaningful title.
    if (isNewChat) unawaited(_nameChat(conversationId, text, finalText));

    // Step 5 (Phase 10): if the answer has artifacts, save them as versions
    // and open the newest in the side panel (on wide screens).
    final artifacts = artifactsIn(finalText);
    if (artifacts.isEmpty) return;
    if (mounted && _width >= _panelBreakpoint) {
      _update(() => _openArtifact = artifacts.last);
    }
    try {
      await widget.services.artifacts.saveVersions(
        uid: uid,
        conversationId: conversationId,
        messageId: messageId,
        blocks: artifacts,
      );
    } catch (error) {
      // Not fatal: the artifact is still in the message itself.
      if (kDebugMode) debugPrint('Save artifact error: $error');
    }
  }

  // ---------- Artifacts side panel ----------

  /// At this chat width or wider the panel sits beside the chat; narrower
  /// screens open it as a full page.
  static const double _panelBreakpoint = 900;

  /// The artifact shown in the side panel (wide screens), or null.
  ArtifactBlock? _openArtifact;

  /// Latest width of this screen, from the LayoutBuilder in [build].
  double _width = 0;

  void _showArtifact(ArtifactBlock artifact) {
    if (_width >= _panelBreakpoint) {
      setState(() => _openArtifact = artifact);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: _panel(artifact, onClose: () => Navigator.of(context).pop()),
          ),
        ),
      ),
    );
  }

  Widget _panel(ArtifactBlock artifact, {required VoidCallback onClose}) =>
      ArtifactPanel(
        artifact: artifact,
        repository: widget.services.artifacts,
        uid: widget.uid,
        conversationId: _conversationId,
        onClose: onClose,
      );

  /// If this fails (for example offline), Nova still answers, just without
  /// the user's instructions and memories.
  Future<Personalization> _loadPersonalization() async {
    try {
      return await widget.services.memory
          .loadPersonalization(widget.uid)
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      if (kDebugMode) debugPrint('Personalization not loaded: $error');
      return Personalization.empty;
    }
  }

  /// The chat's project (instructions and notes), or null. Usually instant:
  /// the sidebar keeps projects loaded. If it fails, Nova answers without it.
  Future<Project?> _loadProject() async {
    final id = widget.projectId;
    if (id == null) return null;
    try {
      return await widget.services.projects
          .loadProject(widget.uid, id)
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      if (kDebugMode) debugPrint('Project not loaded: $error');
      return null;
    }
  }

  /// "Remember" button: the user checks and edits the text, then it is
  /// saved. Only the user can save a memory, never the AI (rule 5).
  Future<void> _remember(String messageText) async {
    final text = await showRememberDialog(
      context,
      initialText: suggestMemoryText(messageText),
    );
    if (text == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.services.memory.addMemory(widget.uid, text);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Saved. ${AppConstants.assistantName} will remember '
            'this in all your chats.',
          ),
        ),
      );
    } on MemoryException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (error) {
      if (kDebugMode) debugPrint('Save memory error: $error');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t save that. Check your connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final artifact = _openArtifact;
        final chat = _buildChat(context);
        if (artifact == null || _width < _panelBreakpoint) return chat;
        return Row(
          children: [
            Expanded(child: chat),
            const VerticalDivider(width: 1),
            SizedBox(
              width: (_width * 0.5).clamp(380, 640),
              child: _panel(
                artifact,
                onClose: () => setState(() => _openArtifact = null),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChat(BuildContext context) {
    final isEmpty =
        _conversationId == null && _pendingUserText == null && !_isStreaming;

    // A new chat shows its own big composer under the greeting; the round
    // one at the bottom appears once the chat has started.
    final showHero = _loaded && isEmpty;

    return Column(
      children: [
        if (widget.projectName != null) _buildProjectLabel(context),
        Expanded(
          child: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : showHero
              ? EmptyChat(
                  firstName: widget.greetingName,
                  onPromptTap: _send,
                  composer: _composer(large: true),
                )
              : Stack(
                  children: [
                    _buildMessageList(),
                    if (_showJumpToLatest)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: IconButton.filledTonal(
                            tooltip: 'Jump to latest',
                            onPressed: _jumpToLatest,
                            icon: const Icon(NovaIcons.jumpToLatest),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        _buildBottom(context, withComposer: !showHero),
      ],
    );
  }

  Widget _composer({bool large = false}) => ChatInput(
    large: large,
    onSend: _send,
    isBusy: _isStreaming,
    onStop: _stop,
    editingText: _editing?.text,
    onCancelEdit: _cancelEdit,
  );

  /// True once Firestore's copy of the message being sent is in [_messages].
  /// Firestore shows a local write almost instantly, long before the server
  /// confirms it, so without this check the message would appear twice.
  bool get _pendingAlreadySaved {
    final pending = _pendingUserText;
    if (pending == null) return true;
    return _messages.any(
      (m) => m.isUser && m.text == pending && !_idsBeforeSend.contains(m.id),
    );
  }

  Widget _buildMessageList() {
    final theme = Theme.of(context);
    // Regenerate: only under the latest answer, right after its question.
    final canRegenerate =
        !_isStreaming &&
        _messages.length >= 2 &&
        !_messages.last.isUser &&
        _messages[_messages.length - 2].isUser;
    // Edit: only the user's latest message.
    final lastUserId = _messages
        .lastWhere(
          (m) => m.isUser,
          orElse: () =>
              const ChatMessage(id: '', role: MessageRole.user, text: ''),
        )
        .id;

    // Top-to-bottom reading order.
    final items = <Widget>[
      for (final m in _messages)
        _highlightable(
          m.id,
          MessageBubble(
            role: m.role,
            text: m.text,
            attachmentKind: m.attachmentKind,
            attachmentName: m.attachmentName,
            previewBytes: _sessionPreviews[m.id],
            onRemember: () => _remember(plainText(m.text)),
            onOpenArtifact: _showArtifact,
            // Only Nova's answers can be saved.
            isSaved: _savedIds.contains(m.id),
            onToggleSave: m.isUser ? null : () => _toggleSave(m),
            rating: _ratings[m.id],
            onRate: m.isUser ? null : (r) => _rate(m, r),
            onRegenerate: canRegenerate && m.id == _messages.last.id
                ? _regenerate
                : null,
            onEdit: !_isStreaming && m.id == lastUserId
                ? () => _startEdit(m)
                : null,
          ),
        ),
      if (_pendingUserText != null && !_pendingAlreadySaved)
        MessageBubble(
          role: MessageRole.user,
          text: _pendingUserText!,
          attachmentKind: _pendingAttachment?.kind,
          attachmentName: _pendingAttachment?.name,
          previewBytes: _pendingAttachment?.kind == AttachmentKind.image
              ? _pendingAttachment!.bytes
              : null,
        ),
      if (_isStreaming && _toolStatus != null)
        Row(
          children: [
            Icon(
              NovaIcons.searchingTools,
              size: NovaSize.icon,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              '$_toolStatus…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      if (_isStreaming)
        MessageBubble(
          role: MessageRole.model,
          text: _streamingText,
          isStreaming: true,
        ),
      if (_error != null)
        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
    ];

    // reverse: true keeps the list pinned to the newest message while the
    // answer grows (auto-scroll). If the user scrolls up to read, a
    // "Jump to latest" button appears instead of yanking them down.
    final reversed = items.reversed.toList();
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 24),
      itemCount: reversed.length,
      itemBuilder: (context, i) => _centered(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: reversed[i],
        ),
      ),
    );
  }

  /// Gives the message being scrolled to a key, and a soft background
  /// while it is highlighted.
  Widget _highlightable(String id, Widget child) {
    final isTarget = id == _highlightId;
    return AnimatedContainer(
      key: isTarget ? _targetKey : null,
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: isTarget
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        borderRadius: BorderRadius.circular(NovaRadius.row),
      ),
      child: child,
    );
  }

  Widget _buildProjectLabel(BuildContext context) {
    return _centered(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(NovaIcons.folder, size: NovaSize.icon),
            label: Text(widget.projectName!, overflow: TextOverflow.ellipsis),
            tooltip: 'Open project',
            onPressed: widget.onOpenProject,
          ),
        ),
      ),
    );
  }

  Widget _buildBottom(BuildContext context, {required bool withComposer}) {
    return SafeArea(
      top: false,
      child: _centered(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NovaSpace.lg,
            0,
            NovaSpace.lg,
            NovaSpace.md,
          ),
          child: Column(
            children: [
              if (withComposer) ...[
                _composer(),
                const SizedBox(height: NovaSpace.sm),
              ],
              Text(
                AppConstants.disclaimer,
                textAlign: TextAlign.center,
                style: NovaText.of(context).caption,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Centres content in a readable column (Studio: 740 px wide).
  static Widget _centered(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: NovaSize.chatMaxWidth),
      child: child,
    ),
  );
}
