import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/career_options.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../data/user_profile.dart';
import 'widgets/selectable_chips.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _headline = TextEditingController();
  final _location = TextEditingController();
  final _customSkill = TextEditingController();
  final _customRole = TextEditingController();

  String? _role;
  String? _experience;
  final Set<String> _skills = {};
  bool _hydrated = false;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _name.dispose();
    _headline.dispose();
    _location.dispose();
    _customSkill.dispose();
    _customRole.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile profile) {
    if (_hydrated) return;
    _hydrated = true;
    _name.text = profile.name;
    _headline.text = profile.headline;
    _location.text = profile.location;
    _role = profile.targetRole.isEmpty ? null : profile.targetRole;
    _experience =
        profile.experienceLevel.isEmpty ? null : profile.experienceLevel;
    _skills.addAll(profile.skills);
    if (_role != null && !CareerOptions.targetRoles.contains(_role)) {
      _customRole.text = _role!;
    }
  }

  Future<void> _pickPhoto(UserProfile profile) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 720,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      await ref.read(profileRepositoryProvider).uploadAvatar(
            uid: profile.uid,
            file: File(picked.path),
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Photo upload failed. Check Firebase Storage rules for your uid.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save(UserProfile profile) async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null || _experience == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a target role and experience.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            uid: profile.uid,
            name: _name.text,
            headline: _headline.text,
            location: _location.text,
            targetRole: _role,
            experienceLevel: _experience,
            skills: _skills.toList(),
            onboardingCompleted: true,
          );
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final uid = ref.watch(currentUserProvider)?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final profileAsync = ref.watch(userProfileProvider(uid));

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: Center(child: Text('Could not load profile.\n$e')),
      ),
      data: (profile) {
        if (profile == null) {
          return const Scaffold(
            body: Center(child: Text('Profile not found')),
          );
        }
        if (!_hydrated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _hydrated) return;
            setState(() => _hydrate(profile));
          });
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Edit profile')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ProfileAvatar(
                        name: profile.name,
                        photoUrl: profile.photoUrl,
                        radius: 48,
                        showEditBadge: true,
                        onTap: _uploadingPhoto
                            ? null
                            : () => _pickPhoto(profile),
                      ),
                      if (_uploadingPhoto)
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text('Tap to change photo',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _headline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Headline (e.g. Flutter dev | Open to internships)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _location,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Location (city, country)',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Target role', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                SelectableChips(
                  options: CareerOptions.targetRoles,
                  selected: {if (_role != null) _role!},
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
                    hintText: 'Custom role',
                    prefixIcon: Icon(Icons.work_outline_rounded),
                  ),
                  onChanged: (value) {
                    setState(() {
                      final trimmed = value.trim();
                      if (trimmed.isNotEmpty) _role = trimmed;
                    });
                  },
                ),
                const SizedBox(height: 24),
                Text('Experience', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                SelectableChips(
                  options: CareerOptions.experienceLevels,
                  selected: {if (_experience != null) _experience!},
                  multi: false,
                  onToggle: (value) => setState(() => _experience = value),
                ),
                const SizedBox(height: 24),
                Text('Skills', style: Theme.of(context).textTheme.titleLarge),
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
                    hintText: 'Add a skill',
                    prefixIcon: const Icon(Icons.add_rounded),
                    suffixIcon: IconButton(
                      onPressed: _addCustomSkill,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _saving ? null : () => _save(profile),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save changes'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
