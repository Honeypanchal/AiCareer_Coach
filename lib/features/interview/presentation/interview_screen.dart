import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/data/profile_repository.dart';
import '../data/interview_models.dart';
import '../data/interview_repository.dart';
import 'interview_history_screen.dart';
import 'interview_setup_sheet.dart';

class InterviewScreen extends ConsumerWidget {
  const InterviewScreen({super.key});

  static const _topics = [
    {
      'label': 'Flutter',
      'icon': Icons.phone_android_rounded,
      'color': 0xFF6C63FF,
    },
    {'label': 'React', 'icon': Icons.web_rounded, 'color': 0xFF61DAFB},
    {'label': 'Python', 'icon': Icons.code_rounded, 'color': 0xFF3776AB},
    {'label': 'DSA', 'icon': Icons.account_tree_rounded, 'color': 0xFF4CAF82},
    {'label': 'Java', 'icon': Icons.coffee_rounded, 'color': 0xFFFF6B35},
    {
      'label': 'HR Round',
      'icon': Icons.people_outline_rounded,
      'color': 0xFFFF5C7D,
    },
    {
      'label': 'System Design',
      'icon': Icons.architecture_rounded,
      'color': 0xFFFFB347,
    },
    {'label': 'SQL', 'icon': Icons.storage_rounded, 'color': 0xFF00BCD4},
    {'label': 'Custom topic', 'icon': Icons.edit_outlined, 'color': 0xFF9090A8},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final role =
        ref.watch(currentUserProfileProvider).valueOrNull?.targetRole ?? '';
    final history = ref.watch(interviewHistoryProvider);
    final sessions = history.valueOrNull ?? const <InterviewSession>[];
    final stats = InterviewStats.from(sessions);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Mock Interview', style: theme.textTheme.displayMedium),
              const SizedBox(height: 6),
              Text(
                'Pick a topic and practice with AI',
                style: theme.textTheme.bodyMedium,
              ),

              const SizedBox(height: 24),

              // ── Stats row ────────────────────────────────────────────────
              Row(
                children: [
                  _StatCard(
                    label: 'Sessions',
                    value: '${stats.sessions}',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Avg Score',
                    value: stats.averageScore == null
                        ? '--'
                        : '${stats.averageScore}%',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Best Topic',
                    value: stats.bestTopic ?? '--',
                    isDark: isDark,
                    small: stats.bestTopic != null,
                  ),
                ],
              ),

              // ── Practice for the profile's target role ───────────────────
              if (role.isNotEmpty) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => showInterviewSetupSheet(context, topic: role),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF9C8FFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recommended for you',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$role interview',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),
              Text('Choose Topic', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),

              // ── Topic grid ───────────────────────────────────────────────
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                itemCount: _topics.length,
                itemBuilder: (context, i) {
                  final topic = _topics[i];
                  final label = topic['label'] as String;
                  final color = Color(topic['color'] as int);
                  return GestureDetector(
                    onTap: () => showInterviewSetupSheet(
                      context,
                      topic: label == 'Custom topic' ? null : label,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2A2A40)
                              : const Color(0xFFEEEEF9),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              topic['icon'] as IconData,
                              color: color,
                              size: 20,
                            ),
                          ),
                          Text(
                            label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent Sessions',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (sessions.isNotEmpty)
                    TextButton(
                      onPressed: () => context.push(AppRoutes.interviewHistory),
                      child: const Text('See all'),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (sessions.isEmpty)
                _EmptyState(
                  isDark: isDark,
                  title: history.hasError
                      ? 'History unavailable'
                      : 'No sessions yet',
                  subtitle: history.hasError
                      ? 'Your sessions could not be loaded right now'
                      : 'Start a mock interview above',
                )
              else
                ...sessions
                    .take(3)
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InterviewSessionTile(session: s),
                      ),
                    ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.isDark,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A40) : const Color(0xFFEEEEF9),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            color: AppColors.textGrey.withValues(alpha: 0.5),
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool small;

  const _StatCard({
    required this.label,
    required this.value,
    required this.isDark,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A40) : const Color(0xFFEEEEF9),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: small ? 14 : 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }
}
