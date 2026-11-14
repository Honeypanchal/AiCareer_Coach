import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../features/auth/data/auth_repository.dart';
import '../../../features/home/presentation/main_scaffold.dart';
import '../../interview/data/interview_models.dart';
import '../../interview/data/interview_repository.dart';
import '../../interview/presentation/widgets/interview_widgets.dart';
import '../../profile/data/profile_repository.dart';
import '../../resume/data/resume_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _goTo(WidgetRef ref, int tab) =>
      ref.read(bottomNavIndexProvider.notifier).state = tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final uid = user?.uid;
    final theme = Theme.of(context);

    final profileAsync = uid != null
        ? ref.watch(userProfileProvider(uid))
        : const AsyncValue.data(null);
    final sessions =
        ref.watch(interviewHistoryProvider).valueOrNull ?? const [];
    final resumes = ref.watch(resumeHistoryProvider).valueOrNull ?? const [];

    final profile = profileAsync.valueOrNull;
    final fullName = profile?.name ?? user?.displayName ?? 'there';
    final firstName = fullName.split(' ').first;
    final targetRole = profile?.targetRole ?? '';
    final photoUrl = profile?.photoUrl ?? user?.photoURL ?? '';
    final stats = InterviewStats.from(sessions);

    return Scaffold(
      body: Stack(
        children: [
          // Soft brand glow behind the header.
          Positioned(
            top: -140,
            right: -120,
            child: GlowCircle(
              size: 340,
              color: AppColors.primary.withValues(
                alpha: AppColors.isDark(context) ? 0.22 : 0.12,
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                // ── Header ────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_greeting()} 👋',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          profileAsync.isLoading
                              ? Container(
                                  width: 120,
                                  height: 30,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.card(context),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                )
                              : Text(
                                  firstName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.displayMedium,
                                ),
                        ],
                      ),
                    ),
                    ProfileAvatar(
                      name: fullName,
                      photoUrl: photoUrl,
                      radius: 23,
                      onTap: () => _goTo(ref, 4),
                    ),
                  ],
                ),
                if (targetRole.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Pill(
                      label: 'Aiming for $targetRole',
                      icon: Icons.flag_rounded,
                    ),
                  ),
                ],
                const SizedBox(height: 22),

                // ── Hero: readiness + start practice ───────────────────────
                _HeroCard(
                  stats: stats,
                  targetRole: targetRole,
                  onStart: () => _goTo(ref, 2),
                ),
                const SizedBox(height: 28),

                // ── Quick actions ─────────────────────────────────────────
                const SectionHeader('Quick actions'),
                const SizedBox(height: 12),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 132,
                  ),
                  children: [
                    _QuickCard(
                      icon: Icons.auto_awesome_rounded,
                      label: 'AI Chat',
                      subtitle: 'Ask your coach',
                      gradient: AppGradients.chat,
                      onTap: () => _goTo(ref, 1),
                    ),
                    _QuickCard(
                      icon: Icons.mic_rounded,
                      label: 'Mock Interview',
                      subtitle: 'Type or speak',
                      gradient: AppGradients.interview,
                      onTap: () => _goTo(ref, 2),
                    ),
                    _QuickCard(
                      icon: Icons.description_rounded,
                      label: 'Resume Check',
                      subtitle: 'Score & improve',
                      gradient: AppGradients.resume,
                      onTap: () => context.push(AppRoutes.resumeCheck),
                    ),
                    _QuickCard(
                      icon: Icons.person_rounded,
                      label: 'Profile',
                      subtitle: 'Role & skills',
                      gradient: AppGradients.profile,
                      onTap: () => _goTo(ref, 4),
                    ),
                  ],
                ),

                // ── Recent activity ───────────────────────────────────────
                if (sessions.isNotEmpty || resumes.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  SectionHeader(
                    'Recent activity',
                    action: sessions.isNotEmpty ? 'See all' : null,
                    onAction: () => context.push(AppRoutes.interviewHistory),
                  ),
                  const SizedBox(height: 8),
                  if (sessions.isNotEmpty)
                    _ActivityTile(
                      icon: Icons.mic_rounded,
                      gradient: AppGradients.interview,
                      title: '${sessions.first.topic} interview',
                      subtitle:
                          '${sessions.first.turns.length} questions · '
                          '${formatShortDate(sessions.first.createdAt)}',
                      score: sessions.first.report.overallScore,
                      onTap: () => context.push(
                        AppRoutes.interviewReport,
                        extra: sessions.first,
                      ),
                    ),
                  if (resumes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ActivityTile(
                      icon: Icons.description_rounded,
                      gradient: AppGradients.resume,
                      title: resumes.first.fileName,
                      subtitle:
                          'Resume review · '
                          '${formatShortDate(resumes.first.createdAt)}',
                      score: resumes.first.overallScore,
                      onTap: () => context.push(
                        AppRoutes.resumeReport,
                        extra: resumes.first,
                      ),
                    ),
                  ],
                ],

                // ── Tips ──────────────────────────────────────────────────
                const SizedBox(height: 28),
                const SectionHeader('Career tips'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: _tips.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => _TipCard(tip: _tips[i]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static const _tips = [
    _Tip(
      Icons.psychology_alt_rounded,
      AppGradients.chat,
      'STAR method',
      'Structure answers as Situation, Task, Action, Result.',
    ),
    _Tip(
      Icons.manage_search_rounded,
      AppGradients.resume,
      'Beat the ATS',
      'Use standard headings and keywords from the job post.',
    ),
    _Tip(
      Icons.record_voice_over_rounded,
      AppGradients.interview,
      'Practice out loud',
      'Speaking answers builds fluency and cuts filler words.',
    ),
    _Tip(
      Icons.travel_explore_rounded,
      AppGradients.info,
      'Research the company',
      'Know their product, mission and recent news.',
    ),
  ];
}

// ─── Hero card ─────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final InterviewStats stats;
  final String targetRole;
  final VoidCallback onStart;

  const _HeroCard({
    required this.stats,
    required this.targetRole,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final score = stats.averageScore;
    final hasStats = stats.sessions > 0 && score != null;

    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: GlowCircle(
              size: 200,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -30,
            child: GlowCircle(
              size: 180,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasStats
                                ? 'Interview readiness'
                                : 'Ready for your next interview?',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            targetRole.isEmpty
                                ? 'Practice with your AI interviewer'
                                : 'Practice for $targetRole',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasStats) ...[
                      const SizedBox(width: 12),
                      _ScoreRing(score: score),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pill(
                      label: hasStats
                          ? '${stats.sessions} session'
                                '${stats.sessions == 1 ? '' : 's'}'
                          : 'Voice answers',
                      icon: hasStats
                          ? Icons.history_rounded
                          : Icons.mic_rounded,
                      onGradient: true,
                    ),
                    Pill(
                      label: hasStats && stats.bestTopic != null
                          ? 'Best: ${stats.bestTopic}'
                          : 'Instant feedback',
                      icon: hasStats
                          ? Icons.emoji_events_rounded
                          : Icons.bolt_rounded,
                      onGradient: true,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: Text(hasStats ? 'Practice again' : 'Start practice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      // Keep it white: no theme gradient here.
                      backgroundBuilder: (context, states, child) => child!,
                      foregroundColor: const Color(0xFF5B4FE8),
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final int score;

  const _ScoreRing({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 74,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 7,
            strokeCap: StrokeCap.round,
            color: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'avg',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick action tile ─────────────────────────────────────────────────────────
class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon: icon, gradient: gradient, size: 42),
              const Spacer(),
              Icon(
                Icons.arrow_outward_rounded,
                size: 18,
                color: AppColors.textGrey.withValues(alpha: 0.7),
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text(context),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

// ─── Recent activity row ───────────────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String subtitle;
  final int score; // 0–100
  final VoidCallback onTap;

  const _ActivityTile({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(score, outOf: 100);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconBadge(icon: icon, gradient: gradient, size: 42, glow: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                  subtitle,
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
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$score%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tips ──────────────────────────────────────────────────────────────────────
class _Tip {
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String body;

  const _Tip(this.icon, this.gradient, this.title, this.body);
}

class _TipCard extends StatelessWidget {
  final _Tip tip;

  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(
              icon: tip.icon,
              gradient: tip.gradient,
              size: 36,
              glow: false,
            ),
            const SizedBox(height: 12),
            Text(
              tip.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text(context),
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tip.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
