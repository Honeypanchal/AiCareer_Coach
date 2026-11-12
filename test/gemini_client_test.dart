import 'package:ai_career_coach/core/ai/gemini_client.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _http(int status, [Object? body]) {
  final request = RequestOptions(path: '/');
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: request, statusCode: status, data: body),
  );
}

void main() {
  test('calls Gemini through Firebase AI Logic, not with a Gemini key', () {
    expect(
      aiLogicUrl('my-project', 'gemini-3.5-flash'),
      'https://firebasevertexai.googleapis.com/v1beta/projects/my-project'
      '/models/gemini-3.5-flash:generateContent',
    );

    const options = FirebaseOptions(
      apiKey: 'firebase-config-key',
      appId: '1:123:web:abc',
      messagingSenderId: '123',
      projectId: 'my-project',
    );
    expect(aiLogicHeaders(options), {
      'Content-Type': 'application/json',
      'x-goog-api-key': 'firebase-config-key',
      'X-Firebase-AppId': '1:123:web:abc',
    });
  });

  group('friendlyAiError', () {
    test('AI Logic not enabled yet', () {
      final error = _http(403, {
        'error': {
          'status': 'PERMISSION_DENIED',
          'details': [
            {'reason': 'SERVICE_DISABLED'},
          ],
        },
      });
      expect(friendlyAiError(error).message, contains('not set up'));
    });

    test('quota, busy and offline', () {
      expect(friendlyAiError(_http(429)).message, contains('Free usage limit'));
      expect(friendlyAiError(_http(503)).message, contains('busy'));
      expect(
        friendlyAiError(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.connectionError,
          ),
        ).message,
        contains('No internet'),
      );
    });
  });

  group('model fallback', () {
    test('lite models get the minimal thinking level instead of budget 0', () {
      const config = {
        'temperature': 0.4,
        'thinkingConfig': {'thinkingBudget': 0},
      };
      expect(configForModel('gemini-3.5-flash', config), config);
      expect(configForModel('gemini-3.5-flash-lite', config), {
        'temperature': 0.4,
        'thinkingConfig': {'thinkingLevel': 'minimal'},
      });
      expect(configForModel('gemini-3.5-flash-lite', {'temperature': 1}), {
        'temperature': 1,
      });
    });

    test('reads a daily quota error and its reset time', () {
      final info = QuotaInfo.fromError({
        'error': {
          'message':
              'Quota exceeded ... Generate content requests per day limit '
              'exceeded on Free Tier. Please retry in 13h59m45s.',
          'details': [
            {
              '@type': 'type.googleapis.com/google.rpc.RetryInfo',
              'retryDelay': '50385s',
            },
          ],
        },
      });
      expect(info.daily, isTrue);
      expect(info.retryAfter, const Duration(seconds: 50385));
    });

    test('a per-minute limit without details waits a minute', () {
      final info = QuotaInfo.fromError({
        'error': {'message': 'Resource has been exhausted'},
      });
      expect(info.daily, isFalse);
      expect(info.retryAfter, const Duration(minutes: 1));
    });

    test('the message says how long to wait', () {
      final now = DateTime(2026, 11, 13, 10);
      expect(
        quotaMessage(now.add(const Duration(seconds: 40)), now: now),
        contains('wait a minute'),
      );
      expect(
        quotaMessage(now.add(const Duration(minutes: 20)), now: now),
        contains('20 minutes'),
      );
      expect(
        quotaMessage(now.add(const Duration(seconds: 50385)), now: now),
        "Today's free AI limit is used up. It resets in about 14 hours.",
      );
    });
  });
}
