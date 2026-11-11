import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final geminiClientProvider = Provider<GeminiClient>((ref) {
  return GeminiClient();
});

// ─── Gemini Exception ──────────────────────────────────────────────────────────
// Carries a message that is safe to show the user.
// retryable tells the send loop whether trying again could help.
class GeminiException implements Exception {
  final String message;
  final bool retryable;

  const GeminiException(this.message, {this.retryable = false});

  @override
  String toString() => message;
}

// ── Read the reply text out of a Gemini response ──────────────────────────────
// A response can have no candidates (blocked prompt) or a candidate with no
// parts (blocked or empty reply), so nothing here can be assumed to exist.
String parseGeminiReply(dynamic data) {
  if (data is! Map) {
    throw const GeminiException('No response received. Please try again.',
        retryable: true);
  }

  final candidates = data['candidates'] as List?;
  if (candidates == null || candidates.isEmpty) {
    if (data['promptFeedback']?['blockReason'] != null) {
      throw const GeminiException(
          "I can't respond to that message. Please try rephrasing it.");
    }
    throw const GeminiException('No response received. Please try again.',
        retryable: true);
  }

  final candidate = candidates.first as Map;
  final finishReason = candidate['finishReason'] as String?;
  final parts = candidate['content']?['parts'] as List? ?? const [];
  final text = parts
      .whereType<Map>()
      .where((part) => part['thought'] != true && part['text'] is String)
      .map((part) => part['text'] as String)
      .join()
      .trim();

  if (text.isEmpty) {
    if (finishReason == 'MAX_TOKENS') {
      throw const GeminiException(
          'That answer was too long to finish. Please ask for a shorter one.');
    }
    if (finishReason == null || finishReason == 'STOP') {
      throw const GeminiException('No response received. Please try again.',
          retryable: true);
    }
    throw const GeminiException(
        "I can't respond to that message. Please try rephrasing it.");
  }

  if (finishReason == 'MAX_TOKENS') {
    return '$text\n\n_This reply was cut off because it got too long. '
        'Ask me to continue._';
  }
  return text;
}

// ─── Gemini Client ─────────────────────────────────────────────────────────────
// One place for the model name, API key, timeouts, retries and error messages.
// Chat, Mock Interview and Resume Check all call Gemini through this class.
class GeminiClient {
  // ── Longer timeouts ────────────────────────────────────────────────────────
  // Gemini can take 15-30 seconds for long responses.
  // Default Dio timeout is ~10s — it was giving up way too early.
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  static const String model = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

  // ── Send a request and return the reply text ──────────────────────────────
  // Auto-retries up to 3 times for network blips and busy servers.
  Future<String> generate({
    required List<Map<String, dynamic>> contents,
    required String systemInstruction,
    Map<String, dynamic> generationConfig = const {},
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw const GeminiException(
          'API key not found. Please check your .env file.');
    }

    final requestBody = {
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'generationConfig': generationConfig,
    };

    const maxRetries = 3;
    int attempt = 0;
    Object? lastError;

    while (attempt < maxRetries) {
      attempt++;
      try {
        final response = await _dio.post(
          _baseUrl,
          data: requestBody,
          options: Options(headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          }),
        );

        return parseGeminiReply(response.data);
      } on DioException catch (e) {
        lastError = e;

        // Don't retry if the request itself is the problem or the free quota
        // is used up (bad key, retired model, rate limit) — retrying won't
        // fix these, and each attempt would use more of the quota.
        final status = e.response?.statusCode;
        if (status != null && status < 500) break;
      } on GeminiException catch (e) {
        lastError = e;
        if (!e.retryable) break;
      } catch (e) {
        lastError = e;
      }

      if (attempt < maxRetries) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    // All retries failed — now show a friendly error
    throw _friendlyError(lastError);
  }

  // ── Send a single prompt and get back JSON matching [schema] ──────────────
  // Gemini's structured output keeps the reply in a fixed shape. If the text
  // still isn't valid JSON (e.g. cut off), it asks once more.
  // [attachments] are extra parts sent before the prompt, e.g. a PDF from
  // [inlinePdf].
  Future<Map<String, dynamic>> generateJson({
    required String prompt,
    required String systemInstruction,
    required Map<String, dynamic> schema,
    double temperature = 0.4,
    List<Map<String, dynamic>> attachments = const [],
    int maxOutputTokens = 8192,
  }) async {
    for (var attempt = 1; ; attempt++) {
      final text = await generate(
        contents: [
          {
            'role': 'user',
            'parts': [
              ...attachments,
              {'text': prompt}
            ],
          }
        ],
        systemInstruction: systemInstruction,
        generationConfig: {
          'temperature': temperature,
          'maxOutputTokens': maxOutputTokens,
          'responseMimeType': 'application/json',
          'responseJsonSchema': schema,
        },
      );

      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
      } on FormatException {
        // Fall through and ask again.
      }

      if (attempt >= 2) {
        throw const GeminiException(
            'The AI sent an unexpected reply. Please try again.');
      }
    }
  }

  /// A PDF sent inline with the request (Gemini accepts PDFs up to 50 MB).
  static Map<String, dynamic> inlinePdf(List<int> bytes) => {
        'inlineData': {
          'mimeType': 'application/pdf',
          'data': base64Encode(bytes),
        }
      };

  // ── Convert errors to friendly messages ───────────────────────────────────
  GeminiException _friendlyError(Object? error) {
    if (error is GeminiException) return error;
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 400) {
        return const GeminiException('Invalid request. Check your API key.');
      }
      if (status == 401 || status == 403) {
        return const GeminiException('API key invalid or not allowed.');
      }
      if (status == 404) {
        return const GeminiException(
            'This AI model is no longer available. The app needs an update.');
      }
      if (status == 429) {
        return const GeminiException(
            'Free usage limit reached. Please wait a minute and try again.');
      }
      if (status != null && status >= 500) {
        return const GeminiException(
            'Gemini is busy right now. Please try again in a moment.');
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return const GeminiException(
            'Request timed out. Please check your connection and try again.');
      }
      if (error.type == DioExceptionType.connectionError) {
        return const GeminiException(
            'No internet connection. Please check your network.');
      }
    }
    return const GeminiException('Something went wrong. Please try again.');
  }
}
