import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../chat/data/chat_repository.dart';
import '../../interview/presentation/widgets/interview_widgets.dart';
import '../data/resume_models.dart';
import '../data/resume_repository.dart';
import 'widgets/resume_report_view.dart';

class ResumeHistoryScreen extends ConsumerWidget {
  const ResumeHistoryScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this review?'),
        content: const Text('It will be removed from your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(resumeHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Resume history')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.resumeCheck),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New check'),
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _Message(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load history',
          subtitle: 'Check your internet connection and try again.',
        ),
        data: (analyses) {
          if (analyses.isEmpty) {
            return const _Message(
              icon: Icons.description_outlined,
              title: 'No resume checks yet',
              subtitle: 'Your resume reviews show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            itemCount: analyses.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return const Text(
                  'Swipe left on a review to delete it.',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
                );
              }
              final analysis = analyses[i - 1];
              return Dismissible(
                key: ValueKey(analysis.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(context),
                onDismissed: (_) {
                  final uid = ref.read(currentUserUidProvider);
                  if (uid == null) return;
                  ref
                      .read(resumeRepositoryProvider)
                      .deleteAnalysis(uid, analysis.id)
                      .catchError((Object _) {
                        if (context.mounted) {
                          showErrorSnackBar(
                            context,
                            'Could not delete. Please try again.',
                          );
                        }
                      });
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                ),
                child: _AnalysisTile(analysis: analysis),
              );
            },
          );
        },
      ),
    );
  }
}

class _AnalysisTile extends StatelessWidget {
  final ResumeAnalysis analysis;

  const _AnalysisTile({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final score = analysis.overallScore;
    final color = scoreColor(score, outOf: 100);

    return GestureDetector(
      onTap: () => context.push(AppRoutes.resumeReport, extra: analysis),
      child: InterviewCard(
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '$score%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (analysis.targetRole.isNotEmpty) analysis.targetRole,
                      formatShortDate(analysis.createdAt),
                      if (analysis.improvedResume != null) 'Improved CV',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}

/// A saved review, opened from history.
class ResumeReportScreen extends StatelessWidget {
  final ResumeAnalysis? analysis;

  const ResumeReportScreen({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final analysis = this.analysis;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          analysis == null
              ? 'Resume review'
              : formatShortDate(analysis.createdAt),
        ),
      ),
      body: analysis == null
          ? const Center(child: Text('This review is no longer available.'))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [ResumeReportView(analysis: analysis)],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: analysis.improvedResume != null
                        ? ElevatedButton(
                            onPressed: () => context.push(
                              AppRoutes.improvedResume,
                              extra: analysis.improvedResume,
                            ),
                            child: const Text('View improved CV'),
                          )
                        : const Text(
                            'To create an improved CV, upload this resume again in Resume Check.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: AppColors.textGrey.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGrey, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
