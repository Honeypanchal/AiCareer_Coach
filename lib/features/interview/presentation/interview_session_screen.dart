import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../data/interview_models.dart';
import 'interview_session_controller.dart';
import 'widgets/interview_widgets.dart';

class InterviewSessionScreen extends ConsumerStatefulWidget {
  final InterviewConfig config;

  const InterviewSessionScreen({super.key, required this.config});

  @override
  ConsumerState<InterviewSessionScreen> createState() =>
      _InterviewSessionScreenState();
}

class _InterviewSessionScreenState
    extends ConsumerState<InterviewSessionScreen> {
  final _answer = TextEditingController();
  final _scroll = ScrollController();

  InterviewSessionNotifier get _notifier =>
      ref.read(interviewSessionProvider(widget.config).notifier);

  @override
  void initState() {
    super.initState();
    _answer.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _answer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<bool> _confirmLeave() async {
    final state = ref.read(interviewSessionProvider(widget.config));
    // While the AI is working, a report can't be started at the same time.
    final canReport = state.turns.isNotEmpty &&
        state.phase != InterviewPhase.evaluating &&
        state.phase != InterviewPhase.finishing;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this interview?'),
        content: Text(!canReport
            ? 'If you leave now, this interview will not be saved.'
            : 'You can get your report for the ${state.turns.length} answered question${state.turns.length == 1 ? '' : 's'}, or leave without saving.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'leave'),
            child: const Text('Leave',
                style: TextStyle(color: AppColors.error)),
          ),
          if (canReport)
            TextButton(
              onPressed: () => Navigator.pop(context, 'report'),
              child: const Text('Get report'),
            ),
        ],
      ),
    );

    if (result == 'report') {
      _notifier.finish();
      return false;
    }
    return result == 'leave';
  }

  Future<void> _handleClose() async {
    final state = ref.read(interviewSessionProvider(widget.config));
    if (!state.inProgress || await _confirmLeave()) {
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final state = ref.watch(interviewSessionProvider(config));

    ref.listen(interviewSessionProvider(config), (previous, next) {
      if (previous?.phase != next.phase &&
          (next.phase == InterviewPhase.answering ||
              next.phase == InterviewPhase.feedback ||
              next.phase == InterviewPhase.finished)) {
        if (next.phase == InterviewPhase.answering &&
            previous?.phase == InterviewPhase.feedback) {
          _answer.clear();
        }
        _scrollToTop();
      }
    });

    final showProgress = state.phase != InterviewPhase.finished &&
        state.phase != InterviewPhase.finishing;

    return PopScope(
      canPop: !state.inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(state.phase == InterviewPhase.finished
                ? Icons.arrow_back_ios_new_rounded
                : Icons.close_rounded),
            onPressed: _handleClose,
          ),
          title: Column(
            children: [
              Text(config.topic,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              Text(
                showProgress
                    ? 'Question ${state.questionNumber} of ${config.questionCount} · ${config.difficulty.label}'
                    : 'Interview report',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ],
          ),
          bottom: showProgress
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: state.turns.length / config.questionCount,
                    minHeight: 3,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  ),
                )
              : null,
        ),
        body: SafeArea(child: _body(state)),
      ),
    );
  }

  Widget _body(InterviewSessionState state) {
    switch (state.phase) {
      case InterviewPhase.loadingQuestion:
        return const _Loading(message: 'Preparing your first question…');
      case InterviewPhase.finishing:
        return const _Loading(message: 'Building your report…');
      case InterviewPhase.error:
        return _ErrorView(
          message: state.errorMessage ?? 'Something went wrong.',
          onRetry: _notifier.retry,
          onExit: () => context.pop(),
        );
      case InterviewPhase.answering:
      case InterviewPhase.evaluating:
        return _answerView(state);
      case InterviewPhase.feedback:
        return _feedbackView(state);
      case InterviewPhase.finished:
        return _reportView(state);
    }
  }

  // ── Question + answer box ─────────────────────────────────────────────────
  Widget _answerView(InterviewSessionState state) {
    final evaluating = state.phase == InterviewPhase.evaluating;
    final canSubmit = !evaluating && _answer.text.trim().isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              _QuestionCard(
                question: state.currentQuestion,
                isFollowUp: state.currentIsFollowUp,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _answer,
                enabled: !evaluating,
                minLines: 7,
                maxLines: 14,
                maxLength: 3000,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText:
                      'Type your answer as you would say it in the interview…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tip: explain the idea, give a short example, and mention trade-offs.',
                style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
              ),
              if (evaluating) ...[
                const SizedBox(height: 24),
                const _Loading(
                    message: 'Reviewing your answer…', compact: true),
              ],
            ],
          ),
        ),
        _BottomBar(children: [
          TextButton(
            onPressed: evaluating
                ? null
                : () => _notifier.submitAnswer('', skipped: true),
            child: const Text('Skip'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: canSubmit
                  ? () {
                      FocusScope.of(context).unfocus();
                      _notifier.submitAnswer(_answer.text);
                    }
                  : null,
              child: const Text('Submit answer'),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Feedback on the last answer ───────────────────────────────────────────
  Widget _feedbackView(InterviewSessionState state) {
    final turn = state.turns.last;
    final hasNext = _notifier.hasNextQuestion;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              _QuestionCard(question: turn.question, isFollowUp: turn.isFollowUp),
              const SizedBox(height: 12),
              InterviewCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            turn.skipped ? 'Skipped' : scoreLabel(turn.score * 10),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        ScoreBadge(score: turn.score),
                      ],
                    ),
                    TurnFeedback(turn: turn),
                  ],
                ),
              ),
              if (hasNext && state.nextIsFollowUp) ...[
                const SizedBox(height: 12),
                const Text(
                  'Next up: a follow-up question to strengthen this answer.',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
        _BottomBar(children: [
          if (hasNext) ...[
            TextButton(
              onPressed: _notifier.finish,
              child: const Text('End now'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: _notifier.next,
              child: Text(hasNext ? 'Next question' : 'See my report'),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Final report ──────────────────────────────────────────────────────────
  Widget _reportView(InterviewSessionState state) {
    final session = state.session!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              if (state.saved == false) ...[
                const InterviewCard(
                  borderColor: AppColors.warning,
                  child: Row(children: [
                    Icon(Icons.cloud_off_rounded, color: AppColors.warning),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This report could not be saved to your history. Check your internet connection.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              InterviewReportView(session: session),
            ],
          ),
        ),
        _BottomBar(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => context.pushReplacement(
                AppRoutes.interviewSession,
                extra: InterviewConfig(
                  topic: widget.config.topic,
                  difficulty: widget.config.difficulty,
                  questionCount: widget.config.questionCount,
                  targetRole: widget.config.targetRole,
                  experienceLevel: widget.config.experienceLevel,
                ),
              ),
              child: const Text('Practice again'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Done'),
            ),
          ),
        ]),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final String question;
  final bool isFollowUp;

  const _QuestionCard({required this.question, required this.isFollowUp});

  @override
  Widget build(BuildContext context) {
    return InterviewCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.record_voice_over_outlined,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Interviewer',
                style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            if (isFollowUp)
              const Tag(label: 'Follow-up', color: AppColors.warning),
          ]),
          const SizedBox(height: 12),
          SelectableText(
            question,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final List<Widget> children;

  const _BottomBar({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2A2A40) : const Color(0xFFEEEEF9),
            width: 0.5,
          ),
        ),
      ),
      child: Row(children: children),
    );
  }
}

class _Loading extends StatelessWidget {
  final String message;
  final bool compact;

  const _Loading({required this.message, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(height: 14),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
    return compact ? content : Center(child: content);
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 44, color: AppColors.error),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 6),
            const Text('Your answers so far are kept.',
                style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
            const SizedBox(height: 8),
            TextButton(onPressed: onExit, child: const Text('Exit interview')),
          ],
        ),
      ),
    );
  }
}
