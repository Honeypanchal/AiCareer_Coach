import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../interview/presentation/widgets/interview_widgets.dart';
import '../../data/resume_models.dart';

Color priorityColor(ImprovementPriority priority) {
  switch (priority) {
    case ImprovementPriority.high:
      return AppColors.error;
    case ImprovementPriority.medium:
      return AppColors.warning;
    case ImprovementPriority.low:
      return AppColors.primary;
  }
}

/// The full resume review: score, categories, strengths, fixes and keywords.
class ResumeReportView extends StatelessWidget {
  final ResumeAnalysis analysis;

  const ResumeReportView({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = analysis.overallScore;
    final color = scoreColor(score, outOf: 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Overall score ──────────────────────────────────────────────────
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
                      value: score / 100,
                      strokeWidth: 10,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text('$score%',
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(scoreLabel(score), style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  if (analysis.targetRole.isNotEmpty)
                    Tag(label: analysis.targetRole),
                  if (analysis.usedJobDescription)
                    const Tag(
                        label: 'Matched to job description',
                        color: AppColors.success),
                ],
              ),
              if (analysis.summary.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(analysis.summary,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),

        // ── Category scores ────────────────────────────────────────────────
        const SizedBox(height: 24),
        Text('Score breakdown', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        InterviewCard(
          child: Column(
            children: [
              for (final category in analysis.categories)
                _CategoryRow(category: category),
            ],
          ),
        ),

        // ── Strengths ──────────────────────────────────────────────────────
        if (analysis.strengths.isNotEmpty) ...[
          const SizedBox(height: 12),
          InterviewCard(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            child: PointList(
              title: 'What works well',
              points: analysis.strengths,
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.success,
            ),
          ),
        ],

        // ── Improvements ───────────────────────────────────────────────────
        if (analysis.improvements.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('How to improve', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Most important first', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          for (final item in analysis.improvements)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ImprovementCard(item: item),
            ),
        ],

        // ── Missing keywords ───────────────────────────────────────────────
        if (analysis.missingKeywords.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Missing keywords', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Recruiters and ATS look for these. Add only the ones you really know.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: analysis.missingKeywords
                .map((k) => Tag(label: k, color: AppColors.warning))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryScore category;

  const _CategoryRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(category.score);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(category.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              Text('${category.score}/10',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: category.score / 10,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          if (category.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(category.comment,
                style: const TextStyle(
                    color: AppColors.textGrey, fontSize: 12.5, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _ImprovementCard extends StatelessWidget {
  final ResumeImprovement item;

  const _ImprovementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InterviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Tag(
                label: '${item.priority.label} priority',
                color: priorityColor(item.priority)),
            const SizedBox(width: 8),
            if (item.section.isNotEmpty)
              Expanded(
                child: Text(item.section,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12.5)),
              ),
          ]),
          if (item.issue.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(item.issue,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14, height: 1.4)),
          ],
          if (item.suggestion.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.suggestion,
                style: const TextStyle(fontSize: 13.5, height: 1.4)),
          ],
          if (item.before.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Example(
              label: 'Before',
              text: item.before,
              color: AppColors.textGrey,
              background: isDark
                  ? const Color(0xFF1A1A24)
                  : const Color(0xFFF4F4FB),
            ),
          ],
          if (item.after.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Example(
              label: 'After',
              text: item.after,
              color: AppColors.success,
              background: AppColors.success.withValues(alpha: 0.08),
            ),
          ],
        ],
      ),
    );
  }
}

class _Example extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  final Color background;

  const _Example({
    required this.label,
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SelectableText(text,
              style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
