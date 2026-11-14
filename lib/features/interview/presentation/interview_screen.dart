import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
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
    final theme = Theme.of(context);
    final role =
        ref.watch(currentUserProfileProvider).valueOrNull?.targetRole ?? '';
    final history = ref.watch(interviewHistoryProvider);
    final sessions = history.valueOrNull ?? const <InterviewSession>[];
    final stats = InterviewStats.from(sessions);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mock Interview',
                        style: theme.textTheme.displayMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pick a topic, then type or speak your answers',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _RoundIconButton(
                  icon: Icons.history_rounded,
                  tooltip: 'Interview history',
                  onTap: () => context.push(AppRoutes.interviewHistory),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Stats ───────────────────────────────────────────────────
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _Stat(
                      icon: Icons.layers_rounded,
                      gradient: AppGradients.chat,
                      value: '${stats.sessions}',
                      label: 'Sessions',
                    ),
                    const _StatDivider(),
                    _Stat(
                      icon: Icons.insights_rounded,
                      gradient: AppGradients.interview,
                      value: stats.averageScore == null
                          ? '--'
                          : '${stats.averageScore}%',
                      label: 'Avg score',
                    ),
                    const _StatDivider(),
                    _Stat(
                      icon: Icons.emoji_events_rounded,
                      gradient: AppGradients.resume,
                      value: stats.bestTopic ?? '--',
                      label: 'Best topic',
                    ),
                  ],
                ),
              ),
            ),

            // ── Practice for the profile's target role ─────────────────
            if (role.isNotEmpty) ...[
              const SizedBox(height: 16),
              _RecommendedCard(
                role: role,
                onTap: () => showInterviewSetupSheet(context, topic: role),
              ),
            ],

            const SizedBox(height: 28),
            const SectionHeader('Choose a topic'),
            const SizedBox(height: 12),

            // ── Topic grid ──────────────────────────────────────────────
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 118,
              ),
              itemCount: _topics.length,
              itemBuilder: (context, i) {
                final topic = _topics[i];
                final label = topic['label'] as String;
                final custom = label == 'Custom topic';
                return AppCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => showInterviewSetupSheet(
                    context,
                    topic: custom ? null : label,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(
                        icon: topic['icon'] as IconData,
                        gradient: gradientFrom(Color(topic['color'] as int)),
                        size: 40,
                        glow: false,
                      ),
                      const Spacer(),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        custom ? 'Any role or skill' : 'Start practice',
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 28),
            SectionHeader(
              'Recent sessions',
              action: sessions.isNotEmpty ? 'See all' : null,
              onAction: () => context.push(AppRoutes.interviewHistory),
            ),
            const SizedBox(height: 10),

            if (sessions.isEmpty)
              _EmptyState(
                title: history.hasError
                    ? 'History unavailable'
                    : 'No sessions yet',
                subtitle: history.hasError
                    ? 'Your sessions could not be loaded right now'
                    : 'Pick a topic above to start your first interview',
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
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AppCard(
        onTap: onTap,
        radius: 16,
        padding: const EdgeInsets.all(11),
        child: Icon(icon, size: 22, color: AppColors.text(context)),
      ),
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  final String role;
  final VoidCallback onTap;

  const _RecommendedCard({required this.role, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -40,
                child: GlowCircle(
                  size: 150,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommended for you',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$role interview',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF5B4FE8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final String value;
  final String label;

  const _Stat({
    required this.icon,
    required this.gradient,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            IconBadge(icon: icon, gradient: gradient, size: 32, glow: false),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: value.length > 6 ? 14 : 19,
                fontWeight: FontWeight.w800,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      indent: 6,
      endIndent: 6,
      color: AppColors.border(context),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const IconBadge(
            icon: Icons.mic_none_rounded,
            gradient: AppGradients.interview,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: AppColors.text(context),
              fontWeight: FontWeight.w700,
              fontSize: 15,
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
