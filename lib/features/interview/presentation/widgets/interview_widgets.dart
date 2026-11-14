import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/interview_models.dart';
import '../../data/voice_answer.dart';

// ─── Shared pieces for the interview screens ──────────────────────────────────

Color scoreColor(int score, {int outOf = 10}) {
  final ratio = score / outOf;
  if (ratio >= 0.7) return AppColors.success;
  if (ratio >= 0.4) return AppColors.warning;
  return AppColors.error;
}

String scoreLabel(int percent) {
  if (percent >= 80) return 'Excellent';
  if (percent >= 60) return 'Good';
  if (percent >= 40) return 'Fair';
  return 'Needs work';
}

String formatShortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class InterviewCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const InterviewCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              borderColor ??
              (isDark ? const Color(0xFF2A2A40) : const Color(0xFFEEEEF9)),
          width: borderColor == null ? 0.5 : 1,
        ),
      ),
      child: child,
    );
  }
}

class Tag extends StatelessWidget {
  final String label;
  final Color color;

  const Tag({super.key, required this.label, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ScoreBadge extends StatelessWidget {
  final int score; // 0–10

  const ScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$score/10',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }
}

class PointList extends StatelessWidget {
  final String title;
  final List<String> points;
  final IconData icon;
  final Color color;

  const PointList({
    super.key,
    required this.title,
    required this.points,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p,
                      style: const TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ModelAnswer extends StatelessWidget {
  final String text;

  const ModelAnswer({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Text(
                  'Model answer',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MarkdownBody(
              data: text,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark ? AppColors.textWhite : AppColors.textDark,
                ),
                code: TextStyle(
                  backgroundColor: isDark
                      ? const Color(0xFF0F0F14)
                      : const Color(0xFFF4F4FB),
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Score, what was good, what was missing and the model answer for one turn.
class TurnFeedback extends StatelessWidget {
  final InterviewTurn turn;

  const TurnFeedback({super.key, required this.turn});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (turn.byVoice) VoiceFeedback(turn: turn),
        PointList(
          title: 'What was good',
          points: turn.good,
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
        ),
        PointList(
          title: turn.skipped ? 'Key points to cover' : 'What was missing',
          points: turn.missing,
          icon: Icons.add_circle_outline_rounded,
          color: AppColors.warning,
        ),
        ModelAnswer(text: turn.modelAnswer),
      ],
    );
  }
}

// ─── Voice answer: what was said and how ──────────────────────────────────────
class VoiceFeedback extends StatelessWidget {
  final InterviewTurn turn;

  const VoiceFeedback({super.key, required this.turn});

  @override
  Widget build(BuildContext context) {
    final delivery = turn.delivery;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillerColor = delivery == null || delivery.fillerWords <= 2
        ? AppColors.success
        : delivery.fillerWords <= 6
        ? AppColors.warning
        : AppColors.error;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mic_rounded, size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'What you said',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0F14) : AppColors.lightBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              '"${turn.answer}"',
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (delivery != null) ...[
            const SizedBox(height: 14),
            const Text(
              'How you said it',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag(
                  label: delivery.fillerWords == 0
                      ? 'No filler words'
                      : '${delivery.fillerWords} filler word'
                            '${delivery.fillerWords == 1 ? '' : 's'}',
                  color: fillerColor,
                ),
                Tag(
                  label: delivery.pace.label,
                  color: delivery.pace == SpeakingPace.good
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ),
            PointList(
              title: 'Speaking tips',
              points: delivery.tips,
              icon: Icons.record_voice_over_outlined,
              color: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Final report ──────────────────────────────────────────────────────────────
// Used at the end of a session and when opening one from history.
class InterviewReportView extends StatelessWidget {
  final InterviewSession session;

  const InterviewReportView({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = session.report;
    final color = scoreColor(report.overallScore, outOf: 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterviewCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: report.overallScore / 100,
                      strokeWidth: 10,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        '${report.overallScore}%',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                scoreLabel(report.overallScore),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  Tag(label: session.topic),
                  Tag(label: session.difficulty.label),
                  Tag(
                    label:
                        '${session.turns.length} question${session.turns.length == 1 ? '' : 's'}',
                  ),
                ],
              ),
              if (report.summary.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  report.summary,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        if (report.strongAreas.isNotEmpty ||
            report.weakAreas.isNotEmpty ||
            report.practiceNext.isNotEmpty) ...[
          const SizedBox(height: 12),
          InterviewCard(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PointList(
                  title: 'Strong areas',
                  points: report.strongAreas,
                  icon: Icons.trending_up_rounded,
                  color: AppColors.success,
                ),
                PointList(
                  title: 'Needs work',
                  points: report.weakAreas,
                  icon: Icons.trending_down_rounded,
                  color: AppColors.error,
                ),
                PointList(
                  title: 'Practise next',
                  points: report.practiceNext,
                  icon: Icons.flag_outlined,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Question breakdown', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        ...List.generate(session.turns.length, (i) {
          final turn = session.turns[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InterviewCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(
                    'Q${i + 1}${turn.isFollowUp ? ' · Follow-up' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      turn.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  trailing: ScoreBadge(score: turn.score),
                  children: [
                    Text(
                      turn.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your answer',
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      turn.skipped ? 'Skipped' : turn.answer,
                      style: TextStyle(
                        height: 1.4,
                        fontStyle: turn.skipped
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    TurnFeedback(turn: turn),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
