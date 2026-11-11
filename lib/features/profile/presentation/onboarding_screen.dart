import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/career_options.dart';
import '../../../core/routes/app_routes.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';
import 'widgets/selectable_chips.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String? _role;
  String? _experience;
  final Set<String> _skills = {};
  final _customSkill = TextEditingController();
  final _customRole = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _customSkill.dispose();
    _customRole.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_role == null || _experience == null) {
      _toast('Pick a target role and experience level.');
      return;
    }

    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            uid: uid,
            targetRole: _role,
            experienceLevel: _experience,
            skills: _skills.toList(),
            onboardingCompleted: true,
          );
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      _toast('Could not save profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _addCustomSkill() {
    final value = _customSkill.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _skills.add(value);
      _customSkill.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                children: [
                  Text('Let’s personalize', style: theme.textTheme.displayMedium),
                  const SizedBox(height: 8),
                  Text(
                    'This is used by Chat, Resume Check, and Mock Interview so answers match your goal.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  Text('Target role', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SelectableChips(
                    options: CareerOptions.targetRoles,
                    selected: {
                      if (_role != null) _role!,
                    },
                    multi: false,
                    onToggle: (value) {
                      setState(() => _role = value);
                      _customRole.clear();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customRole,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Or type a custom role',
                      prefixIcon: Icon(Icons.work_outline_rounded),
                    ),
                    onChanged: (value) {
                      setState(() {
                        final trimmed = value.trim();
                        _role = trimmed.isEmpty ? null : trimmed;
                      });
                    },
                  ),
                  const SizedBox(height: 28),
                  Text('Experience', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SelectableChips(
                    options: CareerOptions.experienceLevels,
                    selected: {
                      if (_experience != null) _experience!,
                    },
                    multi: false,
                    onToggle: (value) => setState(() => _experience = value),
                  ),
                  const SizedBox(height: 28),
                  Text('Skills (pick a few)', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SelectableChips(
                    options: {
                      ...CareerOptions.suggestedSkills,
                      ..._skills,
                    }.toList(),
                    selected: _skills,
                    onToggle: (value) {
                      setState(() {
                        if (_skills.contains(value)) {
                          _skills.remove(value);
                        } else {
                          _skills.add(value);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customSkill,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addCustomSkill(),
                    decoration: InputDecoration(
                      hintText: 'Add another skill',
                      prefixIcon: const Icon(Icons.add_rounded),
                      suffixIcon: IconButton(
                        onPressed: _addCustomSkill,
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
