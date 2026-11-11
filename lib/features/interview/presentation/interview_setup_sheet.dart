import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/data/profile_repository.dart';
import '../data/interview_models.dart';

/// Bottom sheet to pick difficulty and number of questions, then start.
/// Pass a null [topic] to let the user type their own.
Future<void> showInterviewSetupSheet(BuildContext context, {String? topic}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _InterviewSetupSheet(topic: topic),
  );
}

class _InterviewSetupSheet extends ConsumerStatefulWidget {
  final String? topic;

  const _InterviewSetupSheet({this.topic});

  @override
  ConsumerState<_InterviewSetupSheet> createState() =>
      _InterviewSetupSheetState();
}

class _InterviewSetupSheetState extends ConsumerState<_InterviewSetupSheet> {
  final _customTopic = TextEditingController();
  InterviewDifficulty? _difficulty;
  int _count = 5;

  @override
  void dispose() {
    _customTopic.dispose();
    super.dispose();
  }

  String get _topic => widget.topic ?? _customTopic.text.trim();

  void _start() {
    if (_topic.isEmpty) return;
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final config = InterviewConfig(
      topic: _topic,
      difficulty: _difficulty ??
          InterviewDifficulty.forExperience(profile?.experienceLevel ?? ''),
      questionCount: _count,
      targetRole: profile?.targetRole ?? '',
      experienceLevel: profile?.experienceLevel ?? '',
    );
    Navigator.pop(context);
    context.push(AppRoutes.interviewSession, extra: config);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final experience = profile?.experienceLevel ?? '';
    final difficulty =
        _difficulty ?? InterviewDifficulty.forExperience(experience);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.topic ?? 'Custom topic',
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                profile?.targetRole.isNotEmpty == true
                    ? 'Questions are tailored to ${profile!.targetRole}'
                        '${experience.isNotEmpty ? ' · $experience' : ''}'
                    : 'Set your target role in Profile for tailored questions',
                style: theme.textTheme.bodyMedium,
              ),
              if (widget.topic == null) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _customTopic,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 60,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Kotlin coroutines, Excel, Leadership',
                    prefixIcon: Icon(Icons.edit_outlined),
                    counterText: '',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Difficulty', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<InterviewDifficulty>(
                  segments: InterviewDifficulty.values
                      .map((d) => ButtonSegment(value: d, label: Text(d.label)))
                      .toList(),
                  selected: {difficulty},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _difficulty = value.first),
                ),
              ),
              const SizedBox(height: 8),
              Text(difficulty.description,
                  style: const TextStyle(
                      color: AppColors.textGrey, fontSize: 12.5)),
              const SizedBox(height: 24),
              Text('Questions', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: InterviewConfig.questionCounts
                    .map((n) => ChoiceChip(
                          label: Text('$n'),
                          selected: _count == n,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _count = n),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'About ${_count * 2}–${_count * 3} min · follow-up questions count toward the total',
                style:
                    const TextStyle(color: AppColors.textGrey, fontSize: 12.5),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _topic.isEmpty ? null : _start,
                child: const Text('Start interview'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
