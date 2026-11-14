import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../chat/presentation/chat_provider.dart';
import '../../home/presentation/main_scaffold.dart';
import '../../interview/presentation/widgets/interview_widgets.dart';
import '../../profile/data/profile_repository.dart';
import '../data/resume_models.dart';
import 'resume_check_controller.dart';
import 'widgets/resume_report_view.dart';

class ResumeCheckScreen extends ConsumerStatefulWidget {
  /// True when shown as a bottom-bar tab: back is then handled by the
  /// home screen, which returns to the Home tab.
  final bool inTab;

  const ResumeCheckScreen({super.key, this.inTab = false});

  @override
  ConsumerState<ResumeCheckScreen> createState() => _ResumeCheckScreenState();
}

class _ResumeCheckScreenState extends ConsumerState<ResumeCheckScreen> {
  final _role = TextEditingController();
  final _jobDescription = TextEditingController();
  final _scroll = ScrollController();
  bool _roleFilled = false;

  ResumeCheckNotifier get _notifier => ref.read(resumeCheckProvider.notifier);

  @override
  void dispose() {
    _role.dispose();
    _jobDescription.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    const pdf = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
      uniformTypeIdentifiers: ['com.adobe.pdf'],
    );
    try {
      final file = await openFile(acceptedTypeGroups: [pdf]);
      if (file == null) return;
      // Check the size before loading a big file into memory.
      if (await file.length() > ResumeCheckNotifier.maxBytes) {
        if (!mounted) return;
        showErrorSnackBar(
          context,
          'This file is larger than 5 MB. Please upload a smaller PDF.',
        );
        return;
      }
      _notifier.setFile(file.name, await file.readAsBytes());
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not open that file.');
    }
  }

  Future<bool> _confirmStop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop checking your resume?'),
        content: const Text(
          'The AI is still working. If you leave now, '
          'this result will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep waiting'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Leave',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _analyze() {
    FocusScope.of(context).unfocus();
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    _notifier.analyze(
      targetRole: _role.text,
      experienceLevel: profile?.experienceLevel ?? '',
      jobDescription: _jobDescription.text,
    );
  }

  Future<void> _openImproved() async {
    final analysis = ref.read(resumeCheckProvider).analysis;
    if (analysis?.improvedResume != null) {
      context.push(AppRoutes.improvedResume, extra: analysis!.improvedResume);
      return;
    }
    await _notifier.improve();
  }

  void _askCoach(ResumeAnalysis analysis) {
    final top = analysis.improvements
        .take(3)
        .map((i) => '- ${i.issue}')
        .join('\n');
    ref.read(chatDraftProvider.notifier).state =
        'I checked my resume${analysis.targetRole.isEmpty ? '' : ' for ${analysis.targetRole}'} '
        'and scored ${analysis.overallScore}%. The main issues were:\n$top\n'
        'Can you help me fix these, starting with the most important one?';
    ref.read(bottomNavIndexProvider.notifier).state = 1;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resumeCheckProvider);

    // Prefill the target role from the profile once it has loaded.
    final profileRole =
        ref.watch(currentUserProfileProvider).valueOrNull?.targetRole ?? '';
    if (!_roleFilled && profileRole.isNotEmpty) {
      _roleFilled = true;
      _role.text = profileRole;
    }

    ref.listen(resumeCheckProvider, (previous, next) {
      if (previous?.phase != next.phase &&
          next.phase == ResumeCheckPhase.result &&
          previous?.phase == ResumeCheckPhase.analyzing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(0);
        });
      }
      final improved = next.analysis?.improvedResume;
      if (previous?.analysis?.improvedResume == null && improved != null) {
        context.push(AppRoutes.improvedResume, extra: improved);
      }
      if (next.fileError != null && previous?.fileError != next.fileError) {
        showErrorSnackBar(context, next.fileError!);
      }
    });

    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Resume Check'),
        actions: [
          if (state.phase == ResumeCheckPhase.result)
            IconButton(
              tooltip: 'Check another resume',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: _notifier.reset,
            ),
          IconButton(
            tooltip: 'Resume history',
            icon: const Icon(Icons.history_rounded),
            onPressed: state.busy
                ? null
                : () => context.push(AppRoutes.resumeHistory),
          ),
        ],
      ),
      body: SafeArea(child: _body(state)),
    );

    if (widget.inTab) return scaffold;

    // While the AI is working, back asks first instead of doing nothing
    // (a silent, blocked back gesture feels like the app has frozen).
    return PopScope(
      canPop: !state.busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmStop() && context.mounted) context.pop();
      },
      child: scaffold,
    );
  }

  Widget _body(ResumeCheckState state) {
    switch (state.phase) {
      case ResumeCheckPhase.idle:
        return _uploadView(state);
      case ResumeCheckPhase.analyzing:
        return const _ProgressSteps(
          steps: [
            'Reading your resume…',
            'Checking ATS formatting…',
            'Scoring it for your target role…',
            'Writing suggestions…',
          ],
        );
      case ResumeCheckPhase.improving:
        return const _ProgressSteps(
          steps: [
            'Rewriting your bullet points…',
            'Applying the suggestions…',
            'Checking every fact against your original…',
          ],
        );
      case ResumeCheckPhase.error:
        return _ErrorView(
          message: state.errorMessage ?? 'Something went wrong.',
          onRetry: _notifier.retry,
          onBack: _notifier.dismissError,
        );
      case ResumeCheckPhase.result:
        return _resultView(state);
    }
  }

  // ── Step 1: upload ────────────────────────────────────────────────────────
  Widget _uploadView(ResumeCheckState state) {
    final theme = Theme.of(context);
    final file = state.file;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              Text(
                'Get your resume reviewed',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'You get a score, what to fix first with examples, missing keywords, and an improved CV you can download.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _pickFile,
                child: InterviewCard(
                  padding: const EdgeInsets.all(20),
                  borderColor: file == null
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.success,
                  child: file == null
                      ? Column(
                          children: [
                            const SizedBox(height: 6),
                            const IconBadge(
                              icon: Icons.upload_file_rounded,
                              gradient: AppGradients.resume,
                              size: 58,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Upload your resume',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.text(context),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'PDF only · up to 5 MB',
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 36,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${file.sizeLabel} · tap to change',
                                    style: const TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: _notifier.removeFile,
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Target role', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              TextField(
                controller: _role,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Flutter Developer',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              InterviewCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: const Icon(
                      Icons.description_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Match a job description',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Optional, makes keywords more precise',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      TextField(
                        controller: _jobDescription,
                        minLines: 4,
                        maxLines: 10,
                        maxLength: 5000,
                        decoration: const InputDecoration(
                          hintText: 'Paste the job description here',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: AppColors.textGrey,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your PDF is sent to Google Gemini for the review and is not stored. Only the review is saved to your history.',
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _BottomBar(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: file == null ? null : _analyze,
                child: const Text('Check my resume'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 2: the review ────────────────────────────────────────────────────
  Widget _resultView(ResumeCheckState state) {
    final analysis = state.analysis!;
    final hasImproved = analysis.improvedResume != null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              if (state.saved == false) ...[
                const InterviewCard(
                  borderColor: AppColors.warning,
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, color: AppColors.warning),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This review could not be saved to your history. Check your internet connection.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ResumeReportView(analysis: analysis),
            ],
          ),
        ),
        _BottomBar(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _askCoach(analysis),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Ask AI Coach'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _openImproved,
                child: Text(hasImproved ? 'View improved CV' : 'Improve my CV'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Spinner with a message that moves through the steps while the AI works.
class _ProgressSteps extends StatefulWidget {
  final List<String> steps;

  const _ProgressSteps({required this.steps});

  @override
  State<_ProgressSteps> createState() => _ProgressStepsState();
}

class _ProgressStepsState extends State<_ProgressSteps> {
  late final Timer _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_step < widget.steps.length - 1) setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                widget.steps[_step],
                key: ValueKey(_step),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This usually takes 15–30 seconds',
              style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final List<Widget> children;

  const _BottomBar({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2A2A40) : const Color(0xFFEEEEF9),
            width: 0.5,
          ),
        ),
      ),
      child: Row(children: children),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: AppColors.error,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.errorText(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
            const SizedBox(height: 8),
            TextButton(onPressed: onBack, child: const Text('Go back')),
          ],
        ),
      ),
    );
  }
}
