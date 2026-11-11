import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/data/chat_repository.dart';
import '../data/interview_models.dart';
import '../data/interview_repository.dart';
import 'widgets/interview_widgets.dart';

class InterviewHistoryScreen extends ConsumerWidget {
  const InterviewHistoryScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this interview?'),
        content: const Text('Its report will be removed from your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(interviewHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Interview history')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _Message(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load history',
          subtitle: 'Check your internet connection and try again.',
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const _Message(
              icon: Icons.mic_none_rounded,
              title: 'No interviews yet',
              subtitle: 'Finished mock interviews and their reports show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: sessions.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return const Text('Swipe left on an interview to delete it.',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 12.5));
              }
              final session = sessions[i - 1];
              return Dismissible(
                key: ValueKey(session.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(context),
                onDismissed: (_) {
                  final uid = ref.read(currentUserUidProvider);
                  if (uid == null) return;
                  ref
                      .read(interviewRepositoryProvider)
                      .deleteSession(uid, session.id)
                      .catchError((Object _) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Could not delete. Please try again.')),
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
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error),
                ),
                child: InterviewSessionTile(session: session),
              );
            },
          );
        },
      ),
    );
  }
}

/// One finished interview in a list; opens its report.
class InterviewSessionTile extends StatelessWidget {
  final InterviewSession session;

  const InterviewSessionTile({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final score = session.report.overallScore;
    final color = scoreColor(score, outOf: 100);

    return GestureDetector(
      onTap: () => context.push(AppRoutes.interviewReport, extra: session),
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
              child: Text('$score%',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.topic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(
                    '${session.difficulty.label} · ${session.turns.length} questions · ${formatShortDate(session.createdAt)}',
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12.5),
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
            Icon(icon, size: 48, color: AppColors.textGrey.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textGrey, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
