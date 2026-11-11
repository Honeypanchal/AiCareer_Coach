// debugState is the way to read a StateNotifier's state from a test.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:ai_career_coach/core/ai/gemini_client.dart';
import 'package:ai_career_coach/features/interview/data/interview_models.dart';
import 'package:ai_career_coach/features/interview/data/interview_repository.dart';
import 'package:ai_career_coach/features/interview/presentation/interview_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeInterviewRepository extends Fake implements InterviewRepository {
  final evaluations = <AnswerEvaluation>[];
  final evaluateCalls = <bool>[]; // wantNextQuestion of each call
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
  }) async {
    evaluateCalls.add(wantNextQuestion);
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

Future<InterviewSessionNotifier> _start(_FakeInterviewRepository repo,
    {InterviewConfig config = _config}) async {
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
      final notifier = await _start(repo,
          config: const InterviewConfig(
            topic: 'SQL',
            difficulty: InterviewDifficulty.medium,
            questionCount: 5,
          ));

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
      final result = parseEvaluation({
        'score': 14,
        'good': ['a', 'b', 'c', 'd'],
        'missing': ['x', ' '],
        'modelAnswer': ' Ideal ',
        'nextQuestion': 'Next?',
        'nextIsFollowUp': true,
      }, skipped: false, wantNextQuestion: true);

      expect(result.score, 10);
      expect(result.good, ['a', 'b', 'c']);
      expect(result.missing, ['x']);
      expect(result.modelAnswer, 'Ideal');
      expect(result.nextIsFollowUp, isTrue);
    });

    test('a skipped question always scores zero', () {
      final result = parseEvaluation(
          {'score': 6, 'good': ['a'], 'nextQuestion': ''},
          skipped: true, wantNextQuestion: false);
      expect(result.score, 0);
      expect(result.good, isEmpty);
      expect(result.nextQuestion, isNull);
    });

    test('a missing next question is an error that can be retried', () {
      expect(
        () => parseEvaluation({'score': 5, 'nextQuestion': ''},
            skipped: false, wantNextQuestion: true),
        throwsA(isA<GeminiException>()
            .having((e) => e.retryable, 'retryable', isTrue)),
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
      expect(prompt(isFollowUp: true), isNot(contains('nextIsFollowUp must be true')));
      expect(prompt(isFollowUp: false, skipped: true),
          isNot(contains('nextIsFollowUp must be true')));
    });

    test('the interviewer prompt includes the profile', () {
      final prompt = buildInterviewerInstruction(const InterviewConfig(
        topic: 'Flutter',
        difficulty: InterviewDifficulty.hard,
        questionCount: 5,
        targetRole: 'Flutter Developer',
        experienceLevel: '3–5 years',
      ));
      expect(prompt, contains('Target role: Flutter Developer'));
      expect(prompt, contains('Hard'));
    });
  });

  group('models', () {
    test('difficulty follows experience', () {
      expect(InterviewDifficulty.forExperience('Student / Fresher'),
          InterviewDifficulty.easy);
      expect(InterviewDifficulty.forExperience('1–3 years'),
          InterviewDifficulty.medium);
      expect(InterviewDifficulty.forExperience('8+ years'),
          InterviewDifficulty.hard);
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
          )
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
}
