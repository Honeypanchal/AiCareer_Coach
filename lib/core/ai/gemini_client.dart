import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
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
    throw const GeminiException(
      'No response received. Please try again.',
      retryable: true,
    );
  }

  final candidates = data['candidates'] as List?;
  if (candidates == null || candidates.isEmpty) {
    if (data['promptFeedback']?['blockReason'] != null) {
      throw const GeminiException(
        "I can't respond to that message. Please try rephrasing it.",
      );
    }
    throw const GeminiException(
      'No response received. Please try again.',
      retryable: true,
    );
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
        'That answer was too long to finish. Please ask for a shorter one.',
      );
    }
    if (finishReason == null || finishReason == 'STOP') {
      throw const GeminiException(
        'No response received. Please try again.',
        retryable: true,
      );
    }
    throw const GeminiException(
      "I can't respond to that message. Please try rephrasing it.",
    );
  }

  if (finishReason == 'MAX_TOKENS') {
    return '$text\n\n_This reply was cut off because it got too long. '
        'Ask me to continue._';
  }
  return text;
}

// ─── Gemini Client ─────────────────────────────────────────────────────────────
// One place for the model name, timeouts, retries and error messages.
// Chat, Mock Interview and Resume Check all call Gemini through this class.
//
// Requests go through Firebase AI Logic (the same endpoint the official
// firebase_ai package uses). Firebase keeps the Gemini key on its servers;
// the app only sends its Firebase config, which is public by design. So no
// secret ships inside the APK or the website: a key inside a web app can be
// read by anyone who opens the site.
class GeminiClient {
  // Gemini can take 15-30 seconds for long responses (a resume review).
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  // Each model has its own free daily quota (gemini-3.5-flash allows only 20
  // requests a day per project). When one runs out, the next one is used, so
  // the app keeps working. Tested through Firebase AI Logic on 2026-11-13.
  static const List<String> models = [
    'gemini-3.5-flash', // best answers
    'gemini-3.5-flash-lite', // separate, larger free quota
  ];

  // Models whose quota ran out, and when they can be used again. Shared by
  // every request in this app session so a used-up model is skipped at once.
  static final Map<String, DateTime> _blockedUntil = {};

  // ── Send a request and return the reply text ──────────────────────────────
  // Auto-retries up to 3 times for network blips and busy servers, and moves
  // to the next model when a model's free quota is used up.
  Future<String> generate({
    required List<Map<String, dynamic>> contents,
    required String systemInstruction,
    Map<String, dynamic> generationConfig = const {},
  }) async {
    final options = Firebase.app().options;
    Object? lastError;

    for (final model in models) {
      final blockedUntil = _blockedUntil[model];
      if (blockedUntil != null && DateTime.now().isBefore(blockedUntil)) {
        continue;
      }

      final requestBody = {
        'contents': contents,
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction},
          ],
        },
        'generationConfig': configForModel(model, generationConfig),
      };

      const maxRetries = 3;
      var nextModel = false;

      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          final response = await _dio.post(
            aiLogicUrl(options.projectId, model),
            data: requestBody,
            options: Options(headers: aiLogicHeaders(options)),
          );

          return parseGeminiReply(response.data);
        } on DioException catch (e) {
          lastError = e;
          final status = e.response?.statusCode;

          // This model's quota is used up, or it was retired: try the next.
          if (status == 429 || status == 404) {
            final quota = QuotaInfo.fromError(e.response?.data);
            _blockedUntil[model] = DateTime.now().add(
              status == 404 ? const Duration(days: 365) : quota.retryAfter,
            );
            nextModel = true;
            break;
          }

          // Don't retry if the request itself is the problem (setup missing,
          // bad request) — retrying won't fix it and would use more quota.
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

      if (!nextModel) break;
    }

    // Every model's quota is used up: say when it comes back.
    if (lastError == null) {
      throw GeminiException(quotaMessage(_earliestUnblock()));
    }
    if (lastError is DioException && lastError.response?.statusCode == 429) {
      throw GeminiException(quotaMessage(_earliestUnblock()));
    }

    // All retries failed — now show a friendly error
    throw friendlyAiError(lastError);
  }

  static DateTime? _earliestUnblock() {
    final now = DateTime.now();
    final times =
        models
            .map((m) => _blockedUntil[m])
            .whereType<DateTime>()
            .where((t) => t.isAfter(now))
            .toList()
          ..sort();
    return times.isEmpty ? null : times.first;
  }

  // ── Send a single prompt and get back JSON matching [schema] ──────────────
  // Gemini's structured output keeps the reply in a fixed shape. If the text
  // still isn't valid JSON (e.g. cut off), it asks once more.
  // [attachments] are extra parts sent before the prompt, e.g. a PDF from
  // [inlinePdf]. [thinkingBudget] limits the model's thinking time (null =
  // the model decides, 0 = off).
  Future<Map<String, dynamic>> generateJson({
    required String prompt,
    required String systemInstruction,
    required Map<String, dynamic> schema,
    double temperature = 0.4,
    List<Map<String, dynamic>> attachments = const [],
    int maxOutputTokens = 8192,
    int? thinkingBudget,
  }) async {
    for (var attempt = 1; ; attempt++) {
      final text = await generate(
        contents: [
          {
            'role': 'user',
            'parts': [
              ...attachments,
              {'text': prompt},
            ],
          },
        ],
        systemInstruction: systemInstruction,
        generationConfig: {
          'temperature': temperature,
          'maxOutputTokens': maxOutputTokens,
          'responseMimeType': 'application/json',
          'responseJsonSchema': schema,
          // the model "thinks" before answering, which can double
          // the wait. 0 turns it off; a small number caps it.
          if (thinkingBudget != null)
            'thinkingConfig': {'thinkingBudget': thinkingBudget},
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
          'The AI sent an unexpected reply. Please try again.',
        );
      }
    }
  }

  /// A PDF sent inline with the request (Gemini accepts PDFs up to 50 MB).
  static Map<String, dynamic> inlinePdf(List<int> bytes) =>
      inlineFile(bytes, 'application/pdf');

  /// Any file sent inline with the request, e.g. a recorded answer.
  /// Inline requests must stay under 20 MB in total.
  static Map<String, dynamic> inlineFile(List<int> bytes, String mimeType) => {
    'inlineData': {'mimeType': mimeType, 'data': base64Encode(bytes)},
  };
}

// ─── Per-model settings ───────────────────────────────────────────────────────
/// Lite models reject `thinkingBudget: 0` ("invalid argument") but accept the
/// "minimal" thinking level, which is just as fast; other models keep the
/// budget the caller asked for.
Map<String, dynamic> configForModel(
  String model,
  Map<String, dynamic> generationConfig,
) {
  if (!model.contains('lite') ||
      !generationConfig.containsKey('thinkingConfig')) {
    return generationConfig;
  }
  return {
    ...generationConfig,
    'thinkingConfig': {'thinkingLevel': 'minimal'},
  };
}

// ─── Quota errors ─────────────────────────────────────────────────────────────
/// What a 429 says about the limit: per day or per minute, and when it resets.
class QuotaInfo {
  final bool daily;
  final Duration retryAfter;

  const QuotaInfo({required this.daily, required this.retryAfter});

  factory QuotaInfo.fromError(Object? body) {
    final error = body is Map ? body['error'] : null;
    final message = error is Map ? '${error['message'] ?? ''}' : '';
    final daily = message.toLowerCase().contains('per day');

    Duration? retry;
    final details = error is Map ? error['details'] : null;
    if (details is List) {
      for (final detail in details) {
        final delay = detail is Map ? detail['retryDelay'] : null;
        final seconds = delay is String
            ? double.tryParse(delay.replaceAll('s', ''))
            : null;
        if (seconds != null) retry = Duration(seconds: seconds.ceil());
      }
    }
    return QuotaInfo(
      daily: daily,
      retryAfter:
          retry ??
          (daily ? const Duration(hours: 1) : const Duration(minutes: 1)),
    );
  }
}

/// The message shown when every model's free quota is used up.
String quotaMessage(DateTime? availableAgain, {DateTime? now}) {
  if (availableAgain == null) {
    return 'Free usage limit reached. Please wait a minute and try again.';
  }
  final wait = availableAgain.difference(now ?? DateTime.now());
  if (wait.inMinutes < 2) {
    return 'Too many requests right now. Please wait a minute and try again.';
  }
  if (wait.inHours < 1) {
    return 'Free usage limit reached. Please try again in ${wait.inMinutes} minutes.';
  }
  final hours = (wait.inMinutes / 60).ceil();
  return "Today's free AI limit is used up. "
      'It resets in about $hours hour${hours == 1 ? '' : 's'}.';
}

// ─── Firebase AI Logic endpoint ───────────────────────────────────────────────
/// Gemini Developer API through Firebase AI Logic.
String aiLogicUrl(String projectId, String model) =>
    'https://firebasevertexai.googleapis.com/v1beta/projects/$projectId'
    '/models/$model:generateContent';

/// The Firebase API key identifies the Firebase project (it is not a secret);
/// the Gemini key itself never leaves Firebase.
Map<String, String> aiLogicHeaders(FirebaseOptions options) => {
  'Content-Type': 'application/json',
  'x-goog-api-key': options.apiKey,
  'X-Firebase-AppId': options.appId,
};

// ── Convert errors to friendly messages ───────────────────────────────────────
GeminiException friendlyAiError(Object? error) {
  if (error is GeminiException) return error;
  if (error is DioException) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final reason = body is Map ? body.toString() : '';

    if (status == 403 &&
        (reason.contains('SERVICE_DISABLED') ||
            reason.contains('firebasevertexai'))) {
      return const GeminiException(
        'The AI service is not set up for this app yet. Please try again later.',
      );
    }
    if (status == 400) {
      return const GeminiException(
        'The AI could not process this request. Please try again.',
      );
    }
    if (status == 401 || status == 403) {
      return const GeminiException('This app is not allowed to use the AI.');
    }
    if (status == 404) {
      return const GeminiException(
        'This AI model is no longer available. The app needs an update.',
      );
    }
    if (status == 429) {
      return const GeminiException(
        'Free usage limit reached. Please wait a minute and try again.',
      );
    }
    if (status != null && status >= 500) {
      return const GeminiException(
        'Gemini is busy right now. Please try again in a moment.',
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const GeminiException(
        'Request timed out. Please check your connection and try again.',
      );
    }
    if (error.type == DioExceptionType.connectionError) {
      return const GeminiException(
        'No internet connection. Please check your network.',
      );
    }
  }
  return const GeminiException('Something went wrong. Please try again.');
}
