import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../features/auth/data/auth_repository.dart';
import '../../../features/home/presentation/main_scaffold.dart';
import '../../profile/data/profile_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final uid = user?.uid;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final profileAsync = uid != null
        ? ref.watch(userProfileProvider(uid))
        : const AsyncValue.data(null);

    final profile = profileAsync.valueOrNull;
    final fullName = profile?.name ?? user?.displayName ?? 'there';
    final firstName = fullName.split(' ').first;
    final targetRole = profile?.targetRole ?? '';
    final photoUrl = profile?.photoUrl ?? user?.photoURL ?? '';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getGreeting(), style: theme.textTheme.bodyMedium),
                      profileAsync.when(
                        loading: () => Container(
                          width: 120, height: 28,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        error: (_, __) => Text(firstName,
                            style: theme.textTheme.displayMedium),
                        data: (_) => Text(firstName,
                            style: theme.textTheme.displayMedium),
                      ),
                      if (targetRole.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Aiming for $targetRole',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                  ProfileAvatar(
                    name: fullName,
                    photoUrl: photoUrl,
                    radius: 24,
                    onTap: () =>
                        ref.read(bottomNavIndexProvider.notifier).state = 3,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF9C8FFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetRole.isEmpty
                          ? 'Ready for your\nnext interview?'
                          : 'Practice for\n$targetRole',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                      ref.read(bottomNavIndexProvider.notifier).state = 2,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Start Practice',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text('Quick Actions', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  _QuickCard(icon: Icons.chat_bubble_outline_rounded,
                      label: 'AI Chat', subtitle: 'Ask anything',
                      color: const Color(0xFF6C63FF),
                      onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 1),
                  _QuickCard(icon: Icons.mic_none_rounded,
                      label: 'Mock Interview', subtitle: 'Practice now',
                      color: const Color(0xFF4CAF82),
                      onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 2),
                  _QuickCard(icon: Icons.description_outlined,
                      label: 'Resume Check', subtitle: 'Analyze CV',
                      color: const Color(0xFFFF9F43),
                      onTap: () => context.push(AppRoutes.resumeCheck)),
                  _QuickCard(icon: Icons.person_outline_rounded,
                      label: 'Profile', subtitle: 'View & edit',
                      color: const Color(0xFFFF5C7D),
                      onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 3),
                ],
              ),
              const SizedBox(height: 28),
              Text('Career Tips', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              ..._tips().map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TipCard(tip: tip, isDark: isDark),
              )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  List<Map<String, String>> _tips() => [
    {'icon': '💡', 'title': 'STAR Method',
      'body': 'Use Situation, Task, Action, Result to structure your answers.'},
    {'icon': '📄', 'title': 'ATS-Friendly Resume',
      'body': 'Use standard headings and keywords from the job description.'},
    {'icon': '🎯', 'title': 'Research the Company',
      'body': "Know the company's mission and recent news before an interview."},
  ];
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _QuickCard({required this.icon, required this.label,
    required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A40) : const Color(0xFFEEEEF9),
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
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: const TextStyle(
                  color: AppColors.textGrey, fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final Map<String, String> tip;
  final bool isDark;
  const _TipCard({required this.tip, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A40) : const Color(0xFFEEEEF9),
          width: 0.5,
        ),
      ),
      child: Row(children: [
        Text(tip['icon']!, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tip['title']!, style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 4),
            Text(tip['body']!, style: const TextStyle(
                color: AppColors.textGrey, fontSize: 13, height: 1.4)),
          ],
        )),
      ]),
    );
  }
}