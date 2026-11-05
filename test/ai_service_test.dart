import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_chat/app/constants.dart';
import 'package:nova_chat/models/chat_message.dart';
import 'package:nova_chat/services/ai_service.dart';

ChatMessage msg(MessageRole role, String text) =>
    ChatMessage(id: text, role: role, text: text);

String textOf(Content c) => (c.parts.single as TextPart).text;

void main() {
  group('friendlyAiMessage', () {
    test('quota errors say "busy, try in a minute"', () {
      final message = friendlyAiMessage(QuotaExceeded('Quota exceeded for x'));
      expect(message, contains('busy'));
      expect(message, contains('minute'));
    });

    test('429 and Google overload also say busy', () {
      expect(
        friendlyAiMessage(ServerException('Server Error [429]')),
        contains('busy'),
      );
      expect(
        friendlyAiMessage(
          FirebaseAIException(
            'Server Error [500]: This model is currently experiencing '
            'high demand.',
          ),
        ),
        contains('busy'),
      );
    });

    test('no internet gets its own message', () {
      expect(
        friendlyAiMessage(Exception('ClientException: Failed to fetch')),
        contains('No connection'),
      );
    });

    test('App Check errors get their own message', () {
      final fromPlugin = friendlyAiMessage(
        FirebaseException(plugin: 'app-check', code: 'fetch-status-error'),
      );
      final fromServer = friendlyAiMessage(
        ServerException('Firebase App Check token is invalid.'),
      );
      expect(fromPlugin, contains('verify'));
      expect(fromServer, contains('verify'));
    });

    test('raw technical text never reaches the user', () {
      final message = friendlyAiMessage(
        ServerException('INTERNAL: stack at foo.dart:42'),
      );
      expect(message, isNot(contains('foo.dart')));
      expect(message, isNot(contains('INTERNAL')));
    });
  });

  group('cleanHistory', () {
    test('merges back-to-back messages from the same side', () {
      final cleaned = cleanHistory([
        msg(MessageRole.user, 'first try'),
        msg(MessageRole.user, 'second try'), // e.g. the first answer failed
        msg(MessageRole.model, 'answer'),
      ]);
      expect(cleaned.map((m) => m.role), [MessageRole.user, MessageRole.model]);
      expect(cleaned.first.text, 'first try\n\nsecond try');
    });

    test('starts with the user and drops empty messages', () {
      final cleaned = cleanHistory([
        msg(MessageRole.model, 'stray answer'),
        msg(MessageRole.user, 'hi'),
        msg(MessageRole.model, '   '),
        msg(MessageRole.model, 'hello!'),
      ]);
      expect(cleaned.map((m) => m.text), ['hi', 'hello!']);
    });
  });

  group('buildContents', () {
    test('ends with the new message and alternates roles', () {
      final contents = buildContents(
        history: [msg(MessageRole.user, 'hi'), msg(MessageRole.model, 'hello')],
        userText: 'how are you?',
      );
      expect(contents.map((c) => c.role), ['user', 'model', 'user']);
      expect(textOf(contents.last), 'how are you?');
    });

    test('uses at most the last 20 saved messages', () {
      final many = [
        for (var i = 0; i < 30; i++)
          msg(i.isEven ? MessageRole.user : MessageRole.model, 'm$i'),
      ];
      final contents = buildContents(history: many, userText: 'new');
      // 20 history messages + the new one.
      expect(contents.length, AppConstants.maxHistoryMessages + 1);
      expect(textOf(contents[contents.length - 2]), 'm29');
    });
  });

  group('Remote Config values', () {
    test('model name: valid Gemini names only, else the default', () {
      expect(validModelName('gemini-3.8-flash'), 'gemini-3.8-flash');
      expect(
        validModelName(' gemini-3.5-flash-lite '),
        'gemini-3.5-flash-lite',
      );
      expect(validModelName(''), isNull);
      expect(validModelName('https://evil.example/model'), isNull);
      expect(AiService(modelName: 'oops').modelName, AiService.defaultModel);
    });

    test('system prompt: empty or huge falls back to the default', () {
      expect(AiService(systemPrompt: '').systemPrompt, defaultSystemPrompt);
      expect(
        AiService(systemPrompt: 'x' * 9000).systemPrompt,
        defaultSystemPrompt,
      );
      expect(AiService(systemPrompt: 'Be brief.').systemPrompt, 'Be brief.');
    });
  });

  group('AiService.streamReply input checks (no network)', () {
    final service = AiService();

    test('empty message is rejected', () {
      expect(
        service.streamReply(history: const [], userText: '   '),
        emitsError(isA<AiFailure>()),
      );
    });

    test('message over the app limit is rejected', () {
      final tooLong = 'a' * (AppConstants.maxUserMessageLength + 1);
      expect(
        service.streamReply(history: const [], userText: tooLong),
        emitsError(isA<AiFailure>()),
      );
    });
  });

  group('cut-short answers', () {
    test('only a normal "stop" counts as a finished answer', () {
      expect(endedEarly(FinishReason.stop), isFalse);
      for (final reason in [
        FinishReason.maxTokens,
        FinishReason.malformedFunctionCall,
        FinishReason.other,
        null,
      ]) {
        expect(endedEarly(reason), isTrue, reason: '$reason');
      }
      expect(cutShortNote, contains('Regenerate'));
    });

    test('a dropped connection is continued; limits and blocks are not', () {
      for (final reason in [
        null,
        FinishReason.other,
        FinishReason.malformedFunctionCall,
      ]) {
        expect(shouldContinue(reason), isTrue, reason: '$reason');
      }
      for (final reason in [
        FinishReason.stop,
        FinishReason.maxTokens,
        FinishReason.safety,
        FinishReason.recitation,
      ]) {
        expect(shouldContinue(reason), isFalse, reason: '$reason');
      }
    });

    test('a continuation sends the partial answer, then asks to go on', () {
      final contents = [Content.text('Summarise them')];
      final request = continuationContents(contents, 'Here is a quick');
      expect(request, hasLength(3));
      expect(request[1].role, 'model');
      expect((request[1].parts.single as TextPart).text, 'Here is a quick');
      expect(request[2].role, 'user');
      expect((request[2].parts.single as TextPart).text, continueInstruction);
    });
  });

  group('system prompt', () {
    test('uses the assistant name and states the AI has no powers', () {
      expect(defaultSystemPrompt, contains(AppConstants.assistantName));
      expect(defaultSystemPrompt, contains('not instructions'));
    });
  });
}
