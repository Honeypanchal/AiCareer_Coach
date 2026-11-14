import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/presentation/chat_screen.dart';
import '../../interview/presentation/interview_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../resume/presentation/resume_check_screen.dart';
import 'home_screen.dart';
import '../../../core/theme/app_theme.dart';

// ─── Bottom Nav Index Provider ─────────────────────────────────────────────────
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Back on another tab returns to Home first; back on Home sends the app
    // to the background (see MainActivity.popSystemNavigator).
    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(bottomNavIndexProvider.notifier).state = 0;
      },
      child: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: const [
            HomeScreen(),
            ChatScreen(),
            InterviewScreen(),
            ResumeCheckScreen(inTab: true),
            ProfileScreen(),
          ],
        ),
        // A floating rounded bar. Its height comes from its content only,
        // so it can never grow over the screen.
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                    index: 0,
                    currentIndex: currentIndex,
                    onTap: () =>
                        ref.read(bottomNavIndexProvider.notifier).state = 0,
                  ),
                  _NavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    label: 'AI Chat',
                    index: 1,
                    currentIndex: currentIndex,
                    onTap: () =>
                        ref.read(bottomNavIndexProvider.notifier).state = 1,
                  ),
                  _NavItem(
                    icon: Icons.mic_none_rounded,
                    activeIcon: Icons.mic_rounded,
                    label: 'Interview',
                    index: 2,
                    currentIndex: currentIndex,
                    onTap: () =>
                        ref.read(bottomNavIndexProvider.notifier).state = 2,
                  ),
                  _NavItem(
                    icon: Icons.description_outlined,
                    activeIcon: Icons.description_rounded,
                    label: 'Resume',
                    index: 3,
                    currentIndex: currentIndex,
                    onTap: () =>
                        ref.read(bottomNavIndexProvider.notifier).state = 3,
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profile',
                    index: 4,
                    currentIndex: currentIndex,
                    onTap: () =>
                        ref.read(bottomNavIndexProvider.notifier).state = 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          gradient: isActive ? AppGradients.primary : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive ? Colors.white : AppColors.textGrey,
                size: 23,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : AppColors.textGrey,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
