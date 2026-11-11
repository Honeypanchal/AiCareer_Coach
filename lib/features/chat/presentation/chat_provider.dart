import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/profile_repository.dart';
import '../data/chat_message.model.dart';
import '../data/chat_repository.dart';

const _welcomeText =
    "Hi! I'm your AI Career Coach 👋\n\nAsk me anything about interviews, resumes, coding doubts, or career guidance!";

// ─── Chat State ────────────────────────────────────────────────────────────────
// Holds everything the UI needs to know about the current chat.
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;     // true while waiting for AI response
  final bool isLoadingHistory; // true while loading old messages from Firestore
  final String? error;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingHistory = false,
    this.error,
  });

  bool get canSend => !isLoading && !isLoadingHistory;

  // copyWith lets us update one field while keeping the rest unchanged
  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isLoadingHistory,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      error: error, // note: no fallback — passing null clears the error
    );
  }
}

// ─── Chat Notifier ─────────────────────────────────────────────────────────────
// This is the "brain" of the chat feature.
// StateNotifier holds the ChatState and exposes methods to modify it.
// The UI watches this and rebuilds automatically when state changes.
class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  final String? _uid;
  final String Function() _careerContext;

  ChatNotifier(
    this._repository,
    this._uid, {
    String Function()? careerContext,
  })  : _careerContext = careerContext ?? (() => ''),
        super(ChatState()) {
    // Load previous chat history when the notifier is created
    _loadHistory();
  }

  // ── Load chat history from Firestore on startup ────────────────────────────
  Future<void> _loadHistory() async {
    if (_uid == null) return;

    state = state.copyWith(isLoadingHistory: true);

    try {
      final history = await _repository.loadChatHistory(_uid);
      if (!mounted) return;

      // If no history, show a welcome message
      state = state.copyWith(
        messages:
            history.isEmpty ? [ChatMessage(text: _welcomeText, isUser: false)] : history,
        isLoadingHistory: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        messages: [ChatMessage(text: _welcomeText, isUser: false)],
        isLoadingHistory: false,
      );
    }
  }

  // ── Send a message ───────────────────────────────────────────────────────────
  // This is the main method called when the user hits send.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || !state.canSend) return;

    // Step 1: Add user message to UI immediately (optimistic update)
    final userMessage = ChatMessage(text: text.trim(), isUser: true);

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    _save(userMessage);
    await _requestReply();
  }

  // ── Ask Gemini to reply to the conversation so far ─────────────────────────
  Future<void> _requestReply() async {
    try {
      // Step 2: Send the FULL conversation to Gemini for context
      final aiResponseText = await _repository.sendMessage(
        state.messages,
        careerContext: _careerContext(),
      );
      if (!mounted) return;

      // Step 3: Add AI response to the chat
      final aiMessage = ChatMessage(text: aiResponseText, isUser: false);

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isLoading: false,
      );

      _save(aiMessage);
    } catch (e) {
      if (!mounted) return;

      // Step 4: On error, show an error bubble in the chat
      final errorMessage = ChatMessage(
        text: e.toString().replaceAll('Exception: ', ''),
        isUser: false,
        isError: true,
      );

      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // ── Save to Firestore (fire and forget — don't block UI) ───────────────────
  // A failed save must not break the chat, the message is still on screen.
  void _save(ChatMessage message) {
    if (_uid == null) return;
    _repository.saveMessage(_uid, message).catchError((Object e) {
      debugPrint('Could not save chat message: $e');
    });
  }

  // ── Retry last message (useful after an error) ─────────────────────────────
  // The user's message is already in the list and in Firestore, so this only
  // removes the error bubble and asks for the reply again.
  Future<void> retryLastMessage() async {
    if (!state.canSend) return;

    final messagesWithoutError =
        state.messages.where((m) => !m.isError).toList();
    if (messagesWithoutError.isEmpty || !messagesWithoutError.last.isUser) {
      return;
    }

    state = state.copyWith(messages: messagesWithoutError, isLoading: true);
    await _requestReply();
  }

  // ── Clear chat ───────────────────────────────────────────────────────────────
  // Returns false if the history could not be deleted.
  Future<bool> clearChat() async {
    try {
      if (_uid != null) {
        await _repository.clearChatHistory(_uid);
      }
    } catch (e) {
      return false;
    }
    if (!mounted) return true;

    state = ChatState(
      messages: [ChatMessage(text: _welcomeText, isUser: false)],
    );
    return true;
  }
}

// Text another screen wants placed in the chat input (e.g. Resume Check's
// "Ask AI Coach"). The chat screen takes it and sets it back to null.
final chatDraftProvider = StateProvider<String?>((ref) => null);

// ─── Chat Provider ─────────────────────────────────────────────────────────────
// StateNotifierProvider exposes the ChatNotifier to the UI.
// The profile is read at send time so editing it doesn't reset the chat.
final chatProvider =
StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  final uid = ref.watch(currentUserUidProvider);
  return ChatNotifier(
    repository,
    uid,
    careerContext: () =>
        ref.read(currentUserProfileProvider).valueOrNull?.careerContext ?? '',
  );
});
