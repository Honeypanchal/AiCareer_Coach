import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/data/chat_repository.dart';
import '../data/interview_models.dart';
import '../data/interview_repository.dart';
import '../data/voice_answer.dart';

enum InterviewPhase {
  loadingQuestion, // waiting for the first question
  answering,
  evaluating, // waiting for feedback (and the next question)
  feedback,
  finishing, // waiting for the final report
  finished,
  error,
}

// ─── Session State ─────────────────────────────────────────────────────────────
class InterviewSessionState {
  final InterviewPhase phase;
  final List<InterviewTurn> turns; // answered questions, with feedback
  final String currentQuestion;
  final bool currentIsFollowUp;
  final String? nextQuestion; // already written by the AI with the feedback
  final bool nextIsFollowUp;
  final InterviewSession? session; // set when finished
  final bool? saved; // null until saving finished
  final String? errorMessage;
  final String? notice; // shown above the answer box, e.g. no speech heard
  final InterviewPhase? phaseBeforeError;

  const InterviewSessionState({
    this.phase = InterviewPhase.loadingQuestion,
    this.turns = const [],
    this.currentQuestion = '',
    this.currentIsFollowUp = false,
    this.nextQuestion,
    this.nextIsFollowUp = false,
    this.session,
    this.saved,
    this.errorMessage,
    this.notice,
    this.phaseBeforeError,
  });

  /// True while the user would lose progress by leaving.
  bool get inProgress =>
      phase != InterviewPhase.finished &&
      !(phase == InterviewPhase.error && turns.isEmpty);

  /// The question number on screen (1-based).
  int get questionNumber =>
      phase == InterviewPhase.feedback ? turns.length : turns.length + 1;

  InterviewSessionState copyWith({
    InterviewPhase? phase,
    List<InterviewTurn>? turns,
    String? currentQuestion,
    bool? currentIsFollowUp,
    String? Function()? nextQuestion,
    bool? nextIsFollowUp,
    InterviewSession? session,
    bool? saved,
    String? errorMessage,
    String? notice,
    InterviewPhase? phaseBeforeError,
  }) {
    return InterviewSessionState(
      phase: phase ?? this.phase,
      turns: turns ?? this.turns,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      currentIsFollowUp: currentIsFollowUp ?? this.currentIsFollowUp,
      nextQuestion: nextQuestion != null ? nextQuestion() : this.nextQuestion,
      nextIsFollowUp: nextIsFollowUp ?? this.nextIsFollowUp,
      session: session ?? this.session,
      saved: saved ?? this.saved,
      errorMessage: errorMessage, // no fallback — passing null clears it
      notice: notice, // same: shown only until the next change
      phaseBeforeError: phaseBeforeError,
    );
  }
}

// ─── Session Notifier ──────────────────────────────────────────────────────────
// Runs one mock interview: question → answer → feedback → … → final report.
class InterviewSessionNotifier extends StateNotifier<InterviewSessionState> {
  final InterviewRepository _repository;
  final InterviewConfig config;
  final String? _uid;
  Future<void> Function()? _retry;

  InterviewSessionNotifier(this._repository, this.config, this._uid)
    : super(const InterviewSessionState()) {
    _loadFirstQuestion();
  }

  Future<void> _loadFirstQuestion() async {
    state = state.copyWith(phase: InterviewPhase.loadingQuestion);
    try {
      final question = await _repository.firstQuestion(config);
      if (!mounted) return;
      state = state.copyWith(
        phase: InterviewPhase.answering,
        currentQuestion: question,
        currentIsFollowUp: false,
      );
    } catch (e) {
      _fail(e, InterviewPhase.loadingQuestion, _loadFirstQuestion);
    }
  }

  // ── Submit (or skip) the answer to the current question ───────────────────
  Future<void> submitAnswer(String answer, {bool skipped = false}) async {
    final text = answer.trim();
    if (!skipped && text.isEmpty) return;
    await _submit(text: skipped ? '' : text, skipped: skipped);
  }

  // ── Submit a spoken answer ────────────────────────────────────────────────
  // One AI call transcribes it, scores it, reviews the delivery and writes
  // the next question.
  Future<void> submitVoiceAnswer(VoiceAnswer voice) async {
    if (voice.wavBytes.isEmpty) return;
    await _submit(text: '', voice: voice);
  }

  Future<void> _submit({
    required String text,
    bool skipped = false,
    VoiceAnswer? voice,
  }) async {
    if (state.phase != InterviewPhase.answering) return;

    final wantNext = state.turns.length + 1 < config.questionCount;
    state = state.copyWith(phase: InterviewPhase.evaluating);

    try {
      final result = await _repository.evaluateAnswer(
        config: config,
        previousTurns: state.turns,
        question: state.currentQuestion,
        isFollowUp: state.currentIsFollowUp,
        answer: text,
        skipped: skipped,
        wantNextQuestion: wantNext,
        voice: voice,
      );
      if (!mounted || state.phase != InterviewPhase.evaluating) return;

      final turn = InterviewTurn(
        question: state.currentQuestion,
        isFollowUp: state.currentIsFollowUp,
        answer: result.transcript ?? text,
        skipped: skipped,
        score: result.score,
        good: result.good,
        missing: result.missing,
        modelAnswer: result.modelAnswer,
        byVoice: voice != null,
        delivery: result.delivery,
      );

      state = state.copyWith(
        phase: InterviewPhase.feedback,
        turns: [...state.turns, turn],
        nextQuestion: () => result.nextQuestion,
        nextIsFollowUp: result.nextIsFollowUp,
      );
    } on NoSpeechException catch (e) {
      // Nothing to retry: let the user record again or type instead.
      if (!mounted) return;
      state = state.copyWith(
        phase: InterviewPhase.answering,
        notice: e.message,
      );
    } catch (e) {
      _fail(
        e,
        InterviewPhase.answering,
        () => _submit(text: text, skipped: skipped, voice: voice),
      );
    }
  }

  bool get hasNextQuestion =>
      state.nextQuestion != null && state.turns.length < config.questionCount;

  // ── Move on from the feedback card ────────────────────────────────────────
  Future<void> next() async {
    if (state.phase != InterviewPhase.feedback) return;
    if (!hasNextQuestion) return finish();

    state = state.copyWith(
      phase: InterviewPhase.answering,
      currentQuestion: state.nextQuestion,
      currentIsFollowUp: state.nextIsFollowUp,
      nextQuestion: () => null,
    );
  }

  // ── Build the report and save the session ─────────────────────────────────
  // Also used for "End interview": only answered questions are counted.
  Future<void> finish() async {
    if (state.turns.isEmpty ||
        state.phase == InterviewPhase.evaluating ||
        state.phase == InterviewPhase.finishing ||
        state.phase == InterviewPhase.finished) {
      return;
    }

    state = state.copyWith(phase: InterviewPhase.finishing);
    try {
      final notes = await _repository.buildReport(
        config: config,
        turns: state.turns,
      );
      if (!mounted) return;

      var session = InterviewSession(
        topic: config.topic,
        difficulty: config.difficulty,
        createdAt: DateTime.now(),
        turns: state.turns,
        report: InterviewReport(
          overallScore: InterviewReport.overallScoreFor(state.turns),
          summary: notes.summary,
          strongAreas: notes.strongAreas,
          weakAreas: notes.weakAreas,
          practiceNext: notes.practiceNext,
        ),
      );

      state = state.copyWith(phase: InterviewPhase.finished, session: session);
      await _save(session);
    } catch (e) {
      _fail(e, InterviewPhase.feedback, finish);
    }
  }

  Future<void> _save(InterviewSession session) async {
    if (_uid == null) {
      state = state.copyWith(saved: false);
      return;
    }
    try {
      await _repository.saveSession(_uid, session);
      if (mounted) state = state.copyWith(saved: true);
    } catch (_) {
      if (mounted) state = state.copyWith(saved: false);
    }
  }

  // ── Errors ────────────────────────────────────────────────────────────────
  void _fail(
    Object error,
    InterviewPhase backTo,
    Future<void> Function() retry,
  ) {
    if (!mounted) return;
    _retry = retry;
    state = state.copyWith(
      phase: InterviewPhase.error,
      errorMessage: error.toString().replaceAll('Exception: ', ''),
      phaseBeforeError: backTo,
    );
  }

  Future<void> retry() async {
    final retry = _retry;
    final backTo = state.phaseBeforeError;
    if (state.phase != InterviewPhase.error ||
        retry == null ||
        backTo == null) {
      return;
    }
    _retry = null;
    state = state.copyWith(phase: backTo);
    await retry();
  }
}

// A new notifier for every InterviewConfig object, dropped when the
// session screen closes.
final interviewSessionProvider = StateNotifierProvider.autoDispose
    .family<InterviewSessionNotifier, InterviewSessionState, InterviewConfig>((
      ref,
      config,
    ) {
      return InterviewSessionNotifier(
        ref.watch(interviewRepositoryProvider),
        config,
        ref.read(currentUserUidProvider),
      );
    });
