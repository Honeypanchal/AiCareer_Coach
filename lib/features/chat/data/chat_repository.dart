import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/gemini_client.dart';
import '../../../core/firebase/app_firestore.dart';
import '../../auth/data/auth_repository.dart';
import 'chat_message.model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(geminiClientProvider));
});

// ── Build the conversation sent to Gemini ────────────────────────────────────
// Error bubbles are UI only. The conversation must also start with a user
// message, which drops the welcome message (and a model reply left at the
// start of a history that was cut off at 50 messages).
List<Map<String, dynamic>> buildGeminiContents(List<ChatMessage> history) {
  return history
      .where((msg) => !msg.isError)
      .skipWhile((msg) => !msg.isUser)
      .map((msg) => {
            'role': msg.isUser ? 'user' : 'model',
            'parts': [
              {'text': msg.text}
            ],
          })
      .toList();
}

// ── Build the system prompt, personalized with the user's profile ─────────────
String buildSystemInstruction(String careerContext) {
  const base = '''You are an AI Career Coach inside a mobile app called "AI Career Coach".
Your job is to help users with:
- Interview preparation (technical & HR)
- Resume improvement tips
- Career guidance and learning roadmaps
- Coding doubts (Flutter, React, Python, Java, DSA, etc.)

Be friendly, concise, and practical. Use markdown formatting (bullet points,
bold, code blocks) when helpful. Keep responses focused — avoid unnecessary
long intros. If asked something completely unrelated to careers/tech/learning,
gently redirect the conversation back to career topics.''';

  if (careerContext.trim().isEmpty) return base;

  return '''$base

Tailor your advice to this user's profile when it is relevant:
$careerContext''';
}

class ChatRepository {
  final GeminiClient _gemini;
  FirebaseFirestore get _firestore => appFirestore;

  ChatRepository(this._gemini);

  // ── Ask Gemini to reply to the conversation ───────────────────────────────
  Future<String> sendMessage(
    List<ChatMessage> conversationHistory, {
    String careerContext = '',
  }) {
    return _gemini.generate(
      contents: buildGeminiContents(conversationHistory),
      systemInstruction: buildSystemInstruction(careerContext),
      generationConfig: {
        'temperature': 0.7,
        // 8192 tokens ≈ 6000 words — enough for any career/coding response.
        'maxOutputTokens': 8192,
      },
    );
  }

  // ── Firestore methods ─────────────────────────────────────────────────────
  Future<void> saveMessage(String uid, ChatMessage message) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chat_messages')
        .add(message.toMap());
  }

  Future<List<ChatMessage>> loadChatHistory(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('chat_messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    return snapshot.docs.reversed
        .map((doc) => ChatMessage.fromMap(doc.data()))
        .toList();
  }

  Future<void> clearChatHistory(String uid) async {
    final collection =
        _firestore.collection('users').doc(uid).collection('chat_messages');

    // Delete in chunks so long histories stay within Firestore's batch limit.
    while (true) {
      final messages = await collection.limit(400).get();
      if (messages.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}

final currentUserUidProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.uid;
});
