import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import 'chat_message.model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

class ChatRepository {
  // ── FIX 1: Longer timeouts ─────────────────────────────────────────────────
  // Gemini can take 15-30 seconds for long responses.
  // Default Dio timeout is ~10s — it was giving up way too early.
  // connectTimeout: time to establish connection
  // receiveTimeout: time to wait for full response to arrive (most important!)
  // sendTimeout: time to upload our request body
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90), // ← was default ~10s, now 90s
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  // ── Main method: send with auto-retry ─────────────────────────────────────
  Future<String> sendMessage(List<ChatMessage> conversationHistory) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not found. Please check your .env file.');
    }

    final contents = conversationHistory.map((msg) {
      return {
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msg.text}
        ],
      };
    }).toList();

    const systemInstruction = {
      'parts': [
        {
          'text': '''You are an AI Career Coach inside a mobile app called "AI Career Coach". 
Your job is to help users with:
- Interview preparation (technical & HR)
- Resume improvement tips
- Career guidance and learning roadmaps
- Coding doubts (Flutter, React, Python, Java, DSA, etc.)

Be friendly, concise, and practical. Use markdown formatting (bullet points, 
bold, code blocks) when helpful. Keep responses focused — avoid unnecessary 
long intros. If asked something completely unrelated to careers/tech/learning, 
gently redirect the conversation back to career topics.'''
        }
      ]
    };

    final requestBody = {
      'contents': contents,
      'systemInstruction': systemInstruction,
      'generationConfig': {
        'temperature': 0.7,
        // ── FIX 2: Increase token limit ────────────────────────────────────
        // 1024 tokens ≈ 750 words — way too short for detailed answers.
        // 8192 tokens ≈ 6000 words — enough for any career/coding response.
        'maxOutputTokens': 8192,
      },
    };

    // ── FIX 3: Auto-retry up to 3 times ────────────────────────────────────
    // If Gemini has a momentary hiccup (network blip, server busy),
    // we wait 2 seconds and try again automatically — up to 3 attempts.
    // Only throws an error to the user if ALL 3 attempts fail.
    const maxRetries = 3;
    int attempt = 0;
    dynamic lastError;

    while (attempt < maxRetries) {
      attempt++;
      try {
        final response = await _dio.post(
          _baseUrl,
          queryParameters: {'key': apiKey},
          data: requestBody,
          options: Options(headers: {'Content-Type': 'application/json'}),
        );

        final candidates = response.data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('No response received. Please try again.');
        }

        final parts = candidates[0]['content']['parts'] as List;
        final text = parts.map((p) => p['text'] as String).join();
        return text.trim();

      } on DioException catch (e) {
        lastError = e;

        // Don't retry if the user's request itself is bad
        // (wrong API key, invalid format) — retrying won't fix these
        final status = e.response?.statusCode;
        if (status == 400 || status == 403) {
          break;
        }

        // For timeouts and server errors, wait then retry
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
        }

      } catch (e) {
        lastError = e;
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    // All retries failed — now show a friendly error
    return _handleFinalError(lastError);
  }

  // ── Convert errors to friendly messages ───────────────────────────────────
  String _handleFinalError(dynamic error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 400) throw Exception('Invalid request. Check your API key.');
      if (status == 403) throw Exception('API key invalid or quota exceeded.');
      if (status == 429) throw Exception('Rate limit hit. Please wait a moment and try again.');
      if (status != null && status >= 500) throw Exception('Gemini server error. Please try again in a moment.');
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw Exception('Request timed out. Please check your connection and try again.');
      }
      if (error.type == DioExceptionType.connectionError) {
        throw Exception('No internet connection. Please check your network.');
      }
    }
    throw Exception('Something went wrong. Please try again.');
  }

  // ── Firestore methods (unchanged) ─────────────────────────────────────────
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
    final messages = await _firestore
        .collection('users')
        .doc(uid)
        .collection('chat_messages')
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

final currentUserUidProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.uid;
});