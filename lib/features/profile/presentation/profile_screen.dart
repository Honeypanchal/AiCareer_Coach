import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final uid = user?.uid;
    final themeMode = ref.watch(themeModeProvider);

    final profileAsync = uid != null
        ? ref.watch(userProfileProvider(uid))
        : const AsyncValue.data(null);

    final profile = profileAsync.valueOrNull;
    final name = profile?.name ?? user?.displayName ?? 'User';
    final email = user?.email ?? profile?.email ?? '';
    final photoUrl = profile?.photoUrl ?? user?.photoURL ?? '';
    final headline = profile?.headline ?? '';
    final role = profile?.targetRole ?? '';
    final experience = profile?.experienceLevel ?? '';
    final skills = profile?.skills ?? const <String>[];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text('Profile', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 16),

            // ── Header card ─────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: AppGradients.hero,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -40,
                    child: GlowCircle(
                      size: 180,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: ProfileAvatar(
                                name: name,
                                photoUrl: photoUrl,
                                radius: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: profileAsync.isLoading
                                  ? const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _ShimmerBar(width: 140, height: 22),
                                        SizedBox(height: 8),
                                        _ShimmerBar(width: 180, height: 14),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.85,
                                            ),
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (headline.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            headline,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                          ],
                        ),
                        if (role.isNotEmpty || experience.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (role.isNotEmpty)
                                  Pill(
                                    label: role,
                                    icon: Icons.flag_rounded,
                                    onGradient: true,
                                  ),
                                if (experience.isNotEmpty)
                                  Pill(
                                    label: experience,
                                    icon: Icons.work_history_rounded,
                                    onGradient: true,
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push(AppRoutes.editProfile),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Edit profile'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 42),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.12,
                              ),
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
            ),

            // ── Skills ──────────────────────────────────────────────────
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skills',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final skill in skills.take(12)) Pill(label: skill),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // ── Menus ───────────────────────────────────────────────────
            const _GroupLabel('Activity'),
            _MenuGroup(
              children: [
                _Tile(
                  icon: Icons.mic_rounded,
                  gradient: AppGradients.interview,
                  label: 'Interview history',
                  onTap: () => context.push(AppRoutes.interviewHistory),
                ),
                _Tile(
                  icon: Icons.description_rounded,
                  gradient: AppGradients.resume,
                  label: 'Resume history',
                  onTap: () => context.push(AppRoutes.resumeHistory),
                ),
              ],
            ),
            const _GroupLabel('Settings'),
            _MenuGroup(
              children: [
                _Tile(
                  icon: Icons.person_rounded,
                  gradient: AppGradients.chat,
                  label: 'Edit profile',
                  onTap: () => context.push(AppRoutes.editProfile),
                ),
                _Tile(
                  icon: Icons.palette_rounded,
                  gradient: AppGradients.profile,
                  label: 'Appearance',
                  subtitle: themeModeLabel(themeMode),
                  onTap: () => context.push(AppRoutes.appearance),
                ),
                _Tile(
                  icon: Icons.lock_rounded,
                  gradient: AppGradients.info,
                  label: 'Change password',
                  onTap: () => context.push(AppRoutes.changePassword),
                ),
                _Tile(
                  icon: Icons.info_rounded,
                  gradient: gradientFrom(AppColors.textGrey),
                  label: 'About PrepPilot',
                  onTap: () => context.push(AppRoutes.about),
                ),
              ],
            ),
            const _GroupLabel('Account'),
            _MenuGroup(
              children: [
                _Tile(
                  icon: Icons.logout_rounded,
                  label: 'Sign out',
                  isDestructive: true,
                  onTap: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) context.go(AppRoutes.login);
                  },
                ),
                _Tile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete account',
                  isDestructive: true,
                  onTap: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently removes your profile, chat history, and files. Enter your password to confirm.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Password'),
              ),
            ],
          ),
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
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      passwordController.dispose();
      return;
    }

    try {
      await ref
          .read(profileRepositoryProvider)
          .deleteAccount(password: passwordController.text);
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, getAuthErrorMessage(e.code));
      }
    } catch (_) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Could not delete account.');
      }
    } finally {
      passwordController.dispose();
    }
  }
}

class _ShimmerBar extends StatelessWidget {
  final double width;
  final double height;

  const _ShimmerBar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;

  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textGrey,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// A card holding menu rows, separated by thin dividers.
class _MenuGroup extends StatelessWidget {
  final List<Widget> children;

  const _MenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 64,
                endIndent: 16,
                color: AppColors.border(context),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Gradient? gradient;
  final String label;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.gradient,
    this.subtitle,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final danger = AppColors.errorText(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            if (isDestructive)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: danger, size: 19),
              )
            else
              IconBadge(
                icon: icon,
                gradient: gradient ?? AppGradients.primary,
                size: 36,
                glow: false,
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? danger : AppColors.text(context),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                ],
              ),
            ),
            if (!isDestructive)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textGrey,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
