// debugState is the way to read a StateNotifier's state from a test.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:typed_data';

import 'package:ai_career_coach/core/ai/gemini_client.dart';
import 'package:ai_career_coach/features/interview/data/interview_models.dart';
import 'package:ai_career_coach/features/interview/data/interview_repository.dart';
import 'package:ai_career_coach/features/interview/data/voice_answer.dart';
import 'package:ai_career_coach/features/interview/presentation/interview_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeInterviewRepository extends Fake implements InterviewRepository {
  final evaluations = <AnswerEvaluation>[];
  final evaluateCalls = <bool>[]; // wantNextQuestion of each call
  final voices = <VoiceAnswer?>[];
  final saved = <InterviewSession>[];
  Object? failNextEvaluation;
  Completer<AnswerEvaluation>? holdEvaluation;
  bool failSave = false;

  @override
  Future<String> firstQuestion(InterviewConfig config) async => 'Q1?';

  @override
  Future<AnswerEvaluation> evaluateAnswer({
    required InterviewConfig config,
    required List<InterviewTurn> previousTurns,
    required String question,
    required bool isFollowUp,
    required String answer,
    required bool skipped,
    required bool wantNextQuestion,
    VoiceAnswer? voice,
  }) async {
    evaluateCalls.add(wantNextQuestion);
    voices.add(voice);
    if (failNextEvaluation != null) {
      final error = failNextEvaluation!;
      failNextEvaluation = null;
      throw error;
    }
    if (holdEvaluation != null) return holdEvaluation!.future;
    return evaluations.removeAt(0);
  }

  @override
  Future<ReportNotes> buildReport({
    required InterviewConfig config,
    required List<InterviewTurn> turns,
  }) async {
    return const ReportNotes(
      summary: 'Solid start.',
      strongAreas: ['Widgets'],
      weakAreas: ['State'],
      practiceNext: ['Practise setState'],
    );
  }

  @override
  Future<String> saveSession(String uid, InterviewSession session) async {
    if (failSave) throw Exception('offline');
    saved.add(session);
    return 'id-1';
  }
}

AnswerEvaluation _eval(int score, {String? next, bool followUp = false}) {
  return AnswerEvaluation(
    score: score,
    good: const ['Good point'],
    missing: const ['Missing point'],
    modelAnswer: 'Ideal answer',
    nextQuestion: next,
    nextIsFollowUp: followUp,
  );
}

const _config = InterviewConfig(
  topic: 'Flutter',
  difficulty: InterviewDifficulty.easy,
  questionCount: 2,
);

Future<InterviewSessionNotifier> _start(
  _FakeInterviewRepository repo, {
  InterviewConfig config = _config,
}) async {
  final notifier = InterviewSessionNotifier(repo, config, 'user-1');
  await Future<void>.delayed(Duration.zero);
  return notifier;
}

void main() {
  group('InterviewSessionNotifier', () {
    test('runs a full interview and saves the report', () async {
      final repo = _FakeInterviewRepository()
        ..evaluations.addAll([
          _eval(3, next: 'Follow-up?', followUp: true),
          _eval(8),
        ]);
      final notifier = await _start(repo);
      expect(notifier.debugState.phase, InterviewPhase.answering);
      expect(notifier.debugState.currentQuestion, 'Q1?');

      await notifier.submitAnswer('My answer');
      expect(notifier.debugState.phase, InterviewPhase.feedback);
      expect(notifier.debugState.turns.single.score, 3);

      await notifier.next();
      expect(notifier.debugState.currentQuestion, 'Follow-up?');
      expect(notifier.debugState.currentIsFollowUp, isTrue);

      await notifier.submitAnswer('Better answer');
      expect(repo.evaluateCalls, [true, false]);
      expect(notifier.hasNextQuestion, isFalse);

      await notifier.next(); // "See my report"
      final state = notifier.debugState;
      expect(state.phase, InterviewPhase.finished);
      expect(state.session!.report.overallScore, 55);
      expect(state.session!.turns.last.isFollowUp, isTrue);
      expect(state.saved, isTrue);
      expect(repo.saved, hasLength(1));
    });

    test('empty answers are ignored and skips score zero', () async {
      final repo = _FakeInterviewRepository()
        ..evaluations.add(_eval(9, next: 'Q2?'));
      final notifier = await _start(repo);

      await notifier.submitAnswer('   ');
      expect(repo.evaluateCalls, isEmpty);

      await notifier.submitAnswer('', skipped: true);
      final turn = notifier.debugState.turns.single;
      expect(turn.skipped, isTrue);
      expect(turn.answer, '');
    });

    test('ending early reports only the answered questions', () async {
      final repo = _FakeInterviewRepository()
        ..evaluations.add(_eval(6, next: 'Q2?'));
      final notifier = await _start(
        repo,
        config: const InterviewConfig(
          topic: 'SQL',
          difficulty: InterviewDifficulty.medium,
          questionCount: 5,
        ),
      );

      await notifier.submitAnswer('Answer');
      await notifier.finish();
      expect(notifier.debugState.phase, InterviewPhase.finished);
      expect(notifier.debugState.session!.turns, hasLength(1));
      expect(notifier.debugState.session!.report.overallScore, 60);
    });

    test('an error keeps progress and retry continues', () async {
      final repo = _FakeInterviewRepository()
        ..failNextEvaluation = const GeminiException('Gemini is busy')
        ..evaluations.add(_eval(7, next: 'Q2?'));
      final notifier = await _start(repo);

      await notifier.submitAnswer('Answer');
      expect(notifier.debugState.phase, InterviewPhase.error);
      expect(notifier.debugState.errorMessage, 'Gemini is busy');

      await notifier.retry();
      expect(notifier.debugState.phase, InterviewPhase.feedback);
      expect(notifier.debugState.turns.single.answer, 'Answer');
    });

    test('report cannot start while an answer is being reviewed', () async {
      final repo = _FakeInterviewRepository()
        ..evaluations.add(_eval(7, next: 'Q2?'));
      final notifier = await _start(repo);
      await notifier.submitAnswer('First');
      await notifier.next();

      repo.holdEvaluation = Completer<AnswerEvaluation>();
      final pending = notifier.submitAnswer('Second');
      await notifier.finish();
      expect(notifier.debugState.phase, InterviewPhase.evaluating);

      repo.holdEvaluation!.complete(_eval(5));
      await pending;
      expect(notifier.debugState.phase, InterviewPhase.feedback);
      expect(notifier.debugState.turns, hasLength(2));
    });

    test('report is still shown when saving fails', () async {
      final repo = _FakeInterviewRepository()
        ..failSave = true
        ..evaluations.addAll([_eval(5, next: 'Q2?'), _eval(5)]);
      final notifier = await _start(repo);
      await notifier.submitAnswer('A');
      await notifier.next();
      await notifier.submitAnswer('B');
      await notifier.next();

      expect(notifier.debugState.phase, InterviewPhase.finished);
      expect(notifier.debugState.saved, isFalse);
    });
  });

  group('parseEvaluation', () {
    test('clamps the score and limits the lists', () {
      final result = parseEvaluation(
        {
          'score': 14,
          'good': ['a', 'b', 'c', 'd'],
          'missing': ['x', ' '],
          'modelAnswer': ' Ideal ',
          'nextQuestion': 'Next?',
          'nextIsFollowUp': true,
        },
        skipped: false,
        wantNextQuestion: true,
      );

      expect(result.score, 10);
      expect(result.good, ['a', 'b', 'c']);
      expect(result.missing, ['x']);
      expect(result.modelAnswer, 'Ideal');
      expect(result.nextIsFollowUp, isTrue);
    });

    test('a skipped question always scores zero', () {
      final result = parseEvaluation(
        {
          'score': 6,
          'good': ['a'],
          'nextQuestion': '',
        },
        skipped: true,
        wantNextQuestion: false,
      );
      expect(result.score, 0);
      expect(result.good, isEmpty);
      expect(result.nextQuestion, isNull);
    });

    test('a missing next question is an error that can be retried', () {
      expect(
        () => parseEvaluation(
          {'score': 5, 'nextQuestion': ''},
          skipped: false,
          wantNextQuestion: true,
        ),
        throwsA(
          isA<GeminiException>().having(
            (e) => e.retryable,
            'retryable',
            isTrue,
          ),
        ),
      );
    });
  });

  group('prompts', () {
    test('a follow-up is only allowed after a new question', () {
      String prompt({required bool isFollowUp, bool skipped = false}) =>
          buildEvaluationPrompt(
            previousTurns: const [],
            question: 'Q',
            isFollowUp: isFollowUp,
            answer: 'A',
            skipped: skipped,
            wantNextQuestion: true,
          );

      expect(prompt(isFollowUp: false), contains('follow-up question'));
      expect(
        prompt(isFollowUp: true),
        isNot(contains('nextIsFollowUp must be true')),
      );
      expect(
        prompt(isFollowUp: false, skipped: true),
        isNot(contains('nextIsFollowUp must be true')),
      );
    });

    test('the interviewer prompt includes the profile', () {
      final prompt = buildInterviewerInstruction(
        const InterviewConfig(
          topic: 'Flutter',
          difficulty: InterviewDifficulty.hard,
          questionCount: 5,
          targetRole: 'Flutter Developer',
          experienceLevel: '3–5 years',
        ),
      );
      expect(prompt, contains('Target role: Flutter Developer'));
      expect(prompt, contains('Hard'));
    });
  });

  group('models', () {
    test('difficulty follows experience', () {
      expect(
        InterviewDifficulty.forExperience('Student / Fresher'),
        InterviewDifficulty.easy,
      );
      expect(
        InterviewDifficulty.forExperience('1–3 years'),
        InterviewDifficulty.medium,
      );
      expect(
        InterviewDifficulty.forExperience('8+ years'),
        InterviewDifficulty.hard,
      );
      expect(InterviewDifficulty.forExperience(''), InterviewDifficulty.medium);
    });

    test('stats use average score and best topic', () {
      InterviewSession session(String topic, int score) => InterviewSession(
        topic: topic,
        difficulty: InterviewDifficulty.easy,
        createdAt: DateTime(2026, 11, 7),
        turns: const [],
        report: InterviewReport(
          overallScore: score,
          summary: '',
          strongAreas: const [],
          weakAreas: const [],
          practiceNext: const [],
        ),
      );

      final stats = InterviewStats.from([
        session('Flutter', 80),
        session('SQL', 40),
        session('Flutter', 60),
      ]);
      expect(stats.sessions, 3);
      expect(stats.averageScore, 60);
      expect(stats.bestTopic, 'Flutter');
      expect(InterviewStats.from(const []).averageScore, isNull);
    });

    test('session survives a save and load round trip', () {
      final original = InterviewSession(
        topic: 'DSA',
        difficulty: InterviewDifficulty.hard,
        createdAt: DateTime(2026, 11, 7, 10, 30),
        turns: const [
          InterviewTurn(
            question: 'Q',
            isFollowUp: true,
            answer: 'A',
            skipped: false,
            score: 7,
            good: ['g'],
            missing: ['m'],
            modelAnswer: 'ideal',
          ),
        ],
        report: const InterviewReport(
          overallScore: 70,
          summary: 's',
          strongAreas: ['x'],
          weakAreas: ['y'],
          practiceNext: ['z'],
        ),
      );

      final loaded = InterviewSession.fromMap('abc', original.toMap());
      expect(loaded.id, 'abc');
      expect(loaded.difficulty, InterviewDifficulty.hard);
      expect(loaded.createdAt, original.createdAt);
      expect(loaded.turns.single.isFollowUp, isTrue);
      expect(loaded.turns.single.score, 7);
      expect(loaded.report.overallScore, 70);
      expect(loaded.report.practiceNext, ['z']);
    });
  });

  group('voice answers', () {
    final voice = VoiceAnswer(
      wavBytes: pcm16ToWav(List.filled(64000, 0)),
      duration: const Duration(seconds: 2),
    );

    test('a WAV header describes 16 kHz mono 16-bit audio', () {
      final wav = pcm16ToWav(List.filled(32000, 1));
      final header = ByteData.sublistView(wav, 0, 44);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(header.getUint32(4, Endian.little), 36 + 32000);
      expect(header.getUint16(22, Endian.little), 1); // mono
      expect(header.getUint32(24, Endian.little), 16000);
      expect(header.getUint16(34, Endian.little), 16);
      expect(header.getUint32(40, Endian.little), 32000);
      expect(wav.length, 44 + 32000);
      expect(pcmDuration(32000), const Duration(seconds: 1));
    });

    test(
      'a spoken answer is sent once and saved with its transcript',
      () async {
        final repo = _FakeInterviewRepository()
          ..evaluations.add(
            const AnswerEvaluation(
              score: 7,
              good: ['Clear'],
              missing: [],
              modelAnswer: 'Ideal',
              nextQuestion: 'Q2?',
              transcript: 'Um, a widget that can change',
              delivery: VoiceDelivery(
                fillerWords: 1,
                pace: SpeakingPace.good,
                tips: ['Pause instead of saying um'],
              ),
            ),
          );
        final notifier = await _start(repo);

        await notifier.submitVoiceAnswer(voice);
        expect(repo.voices.single, same(voice));
        final turn = notifier.debugState.turns.single;
        expect(turn.byVoice, isTrue);
        expect(turn.answer, 'Um, a widget that can change');
        expect(turn.delivery!.fillerWords, 1);
        expect(notifier.debugState.phase, InterviewPhase.feedback);
      },
    );

    test('no speech goes back to the question with a notice', () async {
      final repo = _FakeInterviewRepository()
        ..failNextEvaluation = const NoSpeechException();
      final notifier = await _start(repo);

      await notifier.submitVoiceAnswer(voice);
      expect(notifier.debugState.phase, InterviewPhase.answering);
      expect(notifier.debugState.notice, contains("couldn't hear"));
      expect(notifier.debugState.turns, isEmpty);
    });

    test('parseEvaluation reads the transcript and delivery', () {
      final evaluation = parseEvaluation(
        {
          'transcript': ' So, like, setState rebuilds it ',
          'score': 6,
          'good': ['setState'],
          'missing': ['State object'],
          'modelAnswer': 'Ideal',
          'nextQuestion': 'Next?',
          'nextIsFollowUp': false,
          'delivery': {
            'fillerWords': 2,
            'pace': 'fast',
            'tips': ['Slow down', ' '],
          },
        },
        skipped: false,
        wantNextQuestion: true,
        byVoice: true,
      );
      expect(evaluation.transcript, 'So, like, setState rebuilds it');
      expect(evaluation.delivery!.pace, SpeakingPace.fast);
      expect(evaluation.delivery!.tips, ['Slow down']);
    });

    test('an empty transcript means no speech was heard', () {
      expect(
        () => parseEvaluation(
          {'transcript': '', 'score': 0, 'nextQuestion': 'Next?'},
          skipped: false,
          wantNextQuestion: true,
          byVoice: true,
        ),
        throwsA(isA<NoSpeechException>()),
      );
    });

    test('the voice prompt asks for a transcript and delivery feedback', () {
      final prompt = buildEvaluationPrompt(
        previousTurns: const [],
        question: 'What is a StatefulWidget?',
        isFollowUp: false,
        answer: '',
        skipped: false,
        wantNextQuestion: true,
        byVoice: true,
      );
      expect(prompt, contains('recording is attached'));
      expect(prompt, contains('fillerWords'));
      expect(prompt, isNot(contains('Candidate\'s answer:')));
    });

    test('voice turns survive a save and load round trip', () {
      const turn = InterviewTurn(
        question: 'Q?',
        isFollowUp: false,
        answer: 'Transcript',
        skipped: false,
        score: 7,
        good: [],
        missing: [],
        modelAnswer: 'Ideal',
        byVoice: true,
        delivery: VoiceDelivery(
          fillerWords: 4,
          pace: SpeakingPace.slow,
          tips: ['Be concise'],
        ),
      );
      final loaded = InterviewTurn.fromMap(turn.toMap());
      expect(loaded.byVoice, isTrue);
      expect(loaded.delivery!.fillerWords, 4);
      expect(loaded.delivery!.pace, SpeakingPace.slow);

      // Typed answers from before this feature still load.
      final old = InterviewTurn.fromMap({'question': 'Q?', 'answer': 'A'});
      expect(old.byVoice, isFalse);
      expect(old.delivery, isNull);
    });
  });

  test('the repository sends the recording with the voice schema', () async {
    final gemini = _CapturingGemini();
    final repo = InterviewRepository(gemini);
    final evaluation = await repo.evaluateAnswer(
      config: _config,
      previousTurns: const [],
      question: 'Q?',
      isFollowUp: false,
      answer: '',
      skipped: false,
      wantNextQuestion: true,
      voice: VoiceAnswer(
        wavBytes: pcm16ToWav(List.filled(64000, 0)),
        duration: const Duration(seconds: 2),
      ),
    );

    final schema = gemini.schema!;
    expect(
      schema['required'],
      containsAll(['transcript', 'score', 'delivery']),
    );
    expect((schema['properties'] as Map).keys, contains('nextQuestion'));
    final audio = gemini.attachments.single['inlineData'] as Map;
    expect(audio['mimeType'], 'audio/wav');
    expect(evaluation.transcript, 'Hello');
    expect(evaluation.delivery!.fillerWords, 0);
  });
}

class _CapturingGemini extends Fake implements GeminiClient {
  Map<String, dynamic>? schema;
  List<Map<String, dynamic>> attachments = const [];

  @override
  Future<Map<String, dynamic>> generateJson({
    required String prompt,
    required String systemInstruction,
    required Map<String, dynamic> schema,
    double temperature = 0.4,
    List<Map<String, dynamic>> attachments = const [],
    int maxOutputTokens = 8192,
    int? thinkingBudget,
  }) async {
    this.schema = schema;
    this.attachments = attachments;
    return {
      'transcript': 'Hello',
      'score': 5,
      'good': <String>[],
      'missing': <String>[],
      'modelAnswer': 'Ideal',
      'nextQuestion': 'Next?',
      'nextIsFollowUp': false,
      'delivery': {'fillerWords': 0, 'pace': 'good', 'tips': <String>[]},
    };
  }
}
