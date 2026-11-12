import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final uid = user?.uid;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 32),
              ProfileAvatar(name: name, photoUrl: photoUrl, radius: 44),
              const SizedBox(height: 16),
              profileAsync.when(
                loading: () => Column(
                  children: [
                    _ShimmerBar(width: 140, height: 24, isDark: isDark),
                    const SizedBox(height: 8),
                    _ShimmerBar(width: 200, height: 16, isDark: isDark),
                  ],
                ),
                error: (_, __) => Column(
                  children: [
                    Text(name, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(email, style: theme.textTheme.bodyMedium),
                  ],
                ),
                data: (_) => Column(
                  children: [
                    Text(name, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(email, style: theme.textTheme.bodyMedium),
                    if (headline.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              if (role.isNotEmpty || experience.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (role.isNotEmpty) _InfoChip(label: role, isDark: isDark),
                    if (experience.isNotEmpty)
                      _InfoChip(label: experience, isDark: isDark),
                  ],
                ),
              ],
              if (skills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: skills
                      .take(8)
                      .map(
                        (s) => _InfoChip(label: s, isDark: isDark, small: true),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 28),
              _Tile(
                icon: Icons.person_outline_rounded,
                label: 'Edit profile',
                isDark: isDark,
                onTap: () => context.push(AppRoutes.editProfile),
              ),
              _Tile(
                icon: Icons.mic_none_rounded,
                label: 'Interview history',
                isDark: isDark,
                onTap: () => context.push(AppRoutes.interviewHistory),
              ),
              _Tile(
                icon: Icons.description_outlined,
                label: 'Resume history',
                isDark: isDark,
                onTap: () => context.push(AppRoutes.resumeHistory),
              ),
              _Tile(
                icon: Icons.palette_outlined,
                label: 'Appearance',
                subtitle: themeModeLabel(themeMode),
                isDark: isDark,
                onTap: () => context.push(AppRoutes.appearance),
              ),
              _Tile(
                icon: Icons.lock_outline_rounded,
                label: 'Change password',
                isDark: isDark,
                onTap: () => context.push(AppRoutes.changePassword),
              ),
              _Tile(
                icon: Icons.info_outline_rounded,
                label: 'About',
                isDark: isDark,
                onTap: () => context.push(AppRoutes.about),
              ),
              const SizedBox(height: 12),
              _Tile(
                icon: Icons.logout_rounded,
                label: 'Sign out',
                isDark: isDark,
                isDestructive: true,
                onTap: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go(AppRoutes.login);
                },
              ),
              _Tile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete account',
                isDark: isDark,
                isDestructive: true,
                onTap: () => _confirmDelete(context, ref),
              ),
              const SizedBox(height: 32),
            ],
          ),
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

class _InfoChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final bool small;

  const _InfoChip({
    required this.label,
    required this.isDark,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 10 : 12,
        vertical: small ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  final double width;
  final double height;
  final bool isDark;
  const _ShimmerBar({
    required this.width,
    required this.height,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDark;
  final bool isDestructive;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A40) : const Color(0xFFEEEEF9),
          width: 0.5,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppColors.textGrey, size: 22),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
        trailing: isDestructive
            ? null
            : const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textGrey,
                size: 20,
              ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
