// debugState is the way to read a StateNotifier's state from a test.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:ai_career_coach/core/ai/gemini_client.dart';
import 'package:ai_career_coach/features/chat/data/chat_message.model.dart';
import 'package:ai_career_coach/features/chat/data/chat_repository.dart';
import 'package:ai_career_coach/features/chat/presentation/chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChatRepository extends Fake implements ChatRepository {
  final saved = <ChatMessage>[];
  final requests = <List<ChatMessage>>[];
  final contexts = <String>[];
  Completer<String> reply = Completer<String>();

  @override
  Future<List<ChatMessage>> loadChatHistory(String uid) async => [];

  @override
  Future<void> saveMessage(String uid, ChatMessage message) async {
    saved.add(message);
  }

  @override
  Future<String> sendMessage(
    List<ChatMessage> conversationHistory, {
    String careerContext = '',
  }) {
    requests.add(List.of(conversationHistory));
    contexts.add(careerContext);
    return reply.future;
  }
}

Future<ChatNotifier> _notifier(_FakeChatRepository repo) async {
  final notifier = ChatNotifier(repo, 'user-1',
      careerContext: () => 'Target role: Flutter Developer');
  await Future<void>.delayed(Duration.zero);
  return notifier;
}

void main() {
  group('ChatNotifier', () {
    test('retry does not duplicate the user message', () async {
      final repo = _FakeChatRepository();
      final notifier = await _notifier(repo);

      repo.reply = Completer<String>()..completeError(Exception('failed'));
      await notifier.sendMessage('Hello');
      expect(notifier.debugState.messages.last.isError, isTrue);

      repo.reply = Completer<String>()..complete('Hi there');
      await notifier.retryLastMessage();

      final users = notifier.debugState.messages.where((m) => m.isUser);
      expect(users.length, 1);
      expect(notifier.debugState.messages.any((m) => m.isError), isFalse);
      expect(notifier.debugState.messages.last.text, 'Hi there');
      expect(repo.saved.where((m) => m.isUser).length, 1);
    });

    test('a second send is ignored while waiting for a reply', () async {
      final repo = _FakeChatRepository();
      final notifier = await _notifier(repo);

      final first = notifier.sendMessage('One');
      await notifier.sendMessage('Two');
      expect(repo.requests.length, 1);
      expect(notifier.debugState.messages.where((m) => m.isUser).length, 1);

      repo.reply.complete('Answer');
      await first;
      expect(notifier.debugState.isLoading, isFalse);
    });

    test('profile context is passed with the request', () async {
      final repo = _FakeChatRepository();
      final notifier = await _notifier(repo);

      repo.reply.complete('Answer');
      await notifier.sendMessage('Hello');
      expect(repo.contexts.single, 'Target role: Flutter Developer');
    });
  });

  group('buildGeminiContents', () {
    test('starts with the user and leaves out welcome and errors', () {
      final contents = buildGeminiContents([
        ChatMessage(text: 'Welcome', isUser: false),
        ChatMessage(text: 'Hello', isUser: true),
        ChatMessage(text: 'Failed', isUser: false, isError: true),
        ChatMessage(text: 'Hi', isUser: false),
      ]);

      expect(contents.map((c) => c['role']), ['user', 'model']);
      expect(contents.first['parts'], [
        {'text': 'Hello'}
      ]);
    });
  });

  group('buildSystemInstruction', () {
    test('includes the profile only when there is one', () {
      expect(buildSystemInstruction('Target role: QA'), contains('Target role: QA'));
      expect(buildSystemInstruction('  '), isNot(contains("user's profile")));
    });
  });

  group('parseGeminiReply', () {
    Map<String, dynamic> candidate(List<Map<String, dynamic>>? parts,
            [String finishReason = 'STOP']) =>
        {
          'candidates': [
            {
              if (parts != null) 'content': {'parts': parts},
              'finishReason': finishReason,
            }
          ]
        };

    test('joins text parts and skips thoughts and non-text parts', () {
      final reply = parseGeminiReply(candidate([
        {'text': 'thinking', 'thought': true},
        {'text': 'Hello '},
        {'inlineData': {}},
        {'text': 'world'},
      ]));
      expect(reply, 'Hello world');
    });

    test('blocked prompt is not retried', () {
      expect(
        () => parseGeminiReply({
          'promptFeedback': {'blockReason': 'SAFETY'}
        }),
        throwsA(isA<GeminiException>()
            .having((e) => e.retryable, 'retryable', isFalse)),
      );
    });

    test('blocked reply with no parts gives a clear message', () {
      expect(
        () => parseGeminiReply(candidate(null, 'SAFETY')),
        throwsA(isA<GeminiException>()
            .having((e) => e.retryable, 'retryable', isFalse)
            .having((e) => e.message, 'message', contains('rephrasing'))),
      );
    });

    test('empty reply can be retried', () {
      expect(
        () => parseGeminiReply({'candidates': []}),
        throwsA(isA<GeminiException>()
            .having((e) => e.retryable, 'retryable', isTrue)),
      );
    });

    test('cut off reply keeps the text and says so', () {
      final reply = parseGeminiReply(candidate([
        {'text': 'Partial answer'}
      ], 'MAX_TOKENS'));
      expect(reply, startsWith('Partial answer'));
      expect(reply, contains('cut off'));
    });
  });
}
