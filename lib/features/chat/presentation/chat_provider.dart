import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_message.model.dart';
import '../data/chat_repository.dart';

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

  ChatNotifier(this._repository, this._uid) : super(ChatState()) {
    // Load previous chat history when the notifier is created
    _loadHistory();
  }

  // ── Load chat history from Firestore on startup ────────────────────────────
  Future<void> _loadHistory() async {
    if (_uid == null) return;

    state = state.copyWith(isLoadingHistory: true);

    try {
      final history = await _repository.loadChatHistory(_uid);

      // If no history, show a welcome message
      if (history.isEmpty) {
        state = state.copyWith(
          messages: [
            ChatMessage(
              text:
              "Hi! I'm your AI Career Coach 👋\n\nAsk me anything about interviews, resumes, coding doubts, or career guidance!",
              isUser: false,
            ),
          ],
          isLoadingHistory: false,
        );
      } else {
        state = state.copyWith(messages: history, isLoadingHistory: false);
      }
    } catch (e) {
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  // ── Send a message ───────────────────────────────────────────────────────────
  // This is the main method called when the user hits send.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Step 1: Add user message to UI immediately (optimistic update)
    final userMessage = ChatMessage(text: text.trim(), isUser: true);
    final updatedMessages = [...state.messages, userMessage];

    state = state.copyWith(
      messages: updatedMessages,
      isLoading: true,
      error: null,
    );

    // Save user message to Firestore (fire and forget — don't block UI)
    if (_uid != null) {
      _repository.saveMessage(_uid, userMessage);
    }

    try {
      // Step 2: Send the FULL conversation to Gemini for context
      // We exclude the initial welcome message if it's the only message
      final history = updatedMessages.where((m) => !m.isError).toList();

      final aiResponseText = await _repository.sendMessage(history);

      // Step 3: Add AI response to the chat
      final aiMessage = ChatMessage(text: aiResponseText, isUser: false);

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isLoading: false,
      );

      // Save AI response to Firestore
      if (_uid != null) {
        _repository.saveMessage(_uid, aiMessage);
      }
    } catch (e) {
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

  // ── Retry last message (useful after an error) ─────────────────────────────
  Future<void> retryLastMessage() async {
    // Find the last user message and resend it
    final lastUserMessage = state.messages.lastWhere(
          (m) => m.isUser,
      orElse: () => ChatMessage(text: '', isUser: true),
    );

    if (lastUserMessage.text.isEmpty) return;

    // Remove the error message before retrying
    final messagesWithoutError =
    state.messages.where((m) => !m.isError).toList();

    state = state.copyWith(messages: messagesWithoutError);
    await sendMessage(lastUserMessage.text);
  }

  // ── Clear chat ───────────────────────────────────────────────────────────────
  Future<void> clearChat() async {
    if (_uid != null) {
      await _repository.clearChatHistory(_uid);
    }
    state = ChatState(
      messages: [
        ChatMessage(
          text:
          "Hi! I'm your AI Career Coach 👋\n\nAsk me anything about interviews, resumes, coding doubts, or career guidance!",
          isUser: false,
        ),
      ],
    );
  }
}

// ─── Chat Provider ─────────────────────────────────────────────────────────────
// StateNotifierProvider exposes the ChatNotifier to the UI.
// autoDispose means the chat state resets if the user navigates away
// and comes back — but since we load from Firestore, history persists.
final chatProvider =
StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  final uid = ref.watch(currentUserUidProvider);
  return ChatNotifier(repository, uid);
});