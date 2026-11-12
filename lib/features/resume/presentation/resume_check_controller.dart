import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/data/chat_repository.dart';
import '../data/resume_models.dart';
import '../data/resume_repository.dart';

enum ResumeCheckPhase { idle, analyzing, result, improving, error }

class PickedResume {
  final String name;
  final Uint8List bytes;

  const PickedResume({required this.name, required this.bytes});

  String get sizeLabel {
    final kb = bytes.length / 1024;
    return kb < 1024
        ? '${kb.round()} KB'
        : '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

// ─── Resume Check State ────────────────────────────────────────────────────────
class ResumeCheckState {
  final ResumeCheckPhase phase;
  final PickedResume? file;
  final String? fileError;
  final ResumeAnalysis? analysis;
  final bool? saved; // null until saving finished
  final String? errorMessage;
  final ResumeCheckPhase? phaseBeforeError;

  const ResumeCheckState({
    this.phase = ResumeCheckPhase.idle,
    this.file,
    this.fileError,
    this.analysis,
    this.saved,
    this.errorMessage,
    this.phaseBeforeError,
  });

  bool get busy =>
      phase == ResumeCheckPhase.analyzing ||
      phase == ResumeCheckPhase.improving;

  ResumeCheckState copyWith({
    ResumeCheckPhase? phase,
    PickedResume? Function()? file,
    String? fileError,
    ResumeAnalysis? analysis,
    bool? saved,
    String? errorMessage,
    ResumeCheckPhase? phaseBeforeError,
  }) {
    return ResumeCheckState(
      phase: phase ?? this.phase,
      file: file != null ? file() : this.file,
      fileError: fileError, // no fallback — passing null clears it
      analysis: analysis ?? this.analysis,
      saved: saved ?? this.saved,
      errorMessage: errorMessage, // no fallback — passing null clears it
      phaseBeforeError: phaseBeforeError,
    );
  }
}

// ─── Resume Check Notifier ─────────────────────────────────────────────────────
// Pick a PDF → AI review → (optional) improved CV. The PDF only stays in memory.
class ResumeCheckNotifier extends StateNotifier<ResumeCheckState> {
  final ResumeRepository _repository;
  final String? _uid;
  String _jobDescription = '';
  Future<void> Function()? _retry;

  ResumeCheckNotifier(this._repository, this._uid)
    : super(const ResumeCheckState());

  static const maxBytes = 5 * 1024 * 1024;

  /// Checks the picked file and keeps it if it's a usable PDF.
  void setFile(String name, Uint8List bytes) {
    String? error;
    if (bytes.length > maxBytes) {
      error = 'This file is larger than 5 MB. Please upload a smaller PDF.';
    } else if (bytes.length < 5 ||
        String.fromCharCodes(bytes.sublist(0, 5)) != '%PDF-') {
      error = 'Please choose a PDF file. Word files can be saved as PDF first.';
    }

    state = error == null
        ? state.copyWith(
            file: () => PickedResume(name: name, bytes: bytes),
          )
        : state.copyWith(fileError: error);
  }

  void removeFile() => state = state.copyWith(file: () => null);

  Future<void> analyze({
    required String targetRole,
    String experienceLevel = '',
    String jobDescription = '',
  }) async {
    final file = state.file;
    if (file == null || state.busy) return;
    _jobDescription = jobDescription;

    state = state.copyWith(phase: ResumeCheckPhase.analyzing);
    try {
      var analysis = await _repository.analyze(
        pdfBytes: file.bytes,
        fileName: file.name,
        targetRole: targetRole.trim(),
        experienceLevel: experienceLevel,
        jobDescription: jobDescription,
      );
      if (!mounted) return;
      state = state.copyWith(
        phase: ResumeCheckPhase.result,
        analysis: analysis,
      );

      if (_uid == null) {
        state = state.copyWith(saved: false);
        return;
      }
      try {
        final id = await _repository.saveAnalysis(_uid, analysis);
        analysis = analysis.copyWith(id: id);
        if (mounted) state = state.copyWith(analysis: analysis, saved: true);
      } catch (_) {
        if (mounted) state = state.copyWith(saved: false);
      }
    } catch (e) {
      _fail(
        e,
        ResumeCheckPhase.idle,
        () => analyze(
          targetRole: targetRole,
          experienceLevel: experienceLevel,
          jobDescription: jobDescription,
        ),
      );
    }
  }

  /// Writes the improved CV. Returns true when it is ready to show.
  Future<bool> improve() async {
    final file = state.file;
    final analysis = state.analysis;
    if (file == null || analysis == null || state.busy) return false;
    if (analysis.improvedResume != null) return true;

    state = state.copyWith(phase: ResumeCheckPhase.improving);
    try {
      final improved = await _repository.improve(
        pdfBytes: file.bytes,
        analysis: analysis,
        jobDescription: _jobDescription,
      );
      if (!mounted) return false;
      state = state.copyWith(
        phase: ResumeCheckPhase.result,
        analysis: analysis.copyWith(improvedResume: improved),
      );

      if (_uid != null && analysis.id.isNotEmpty) {
        _repository
            .saveImprovedResume(_uid, analysis.id, improved)
            .catchError((Object _) {});
      }
      return true;
    } catch (e) {
      _fail(e, ResumeCheckPhase.result, () async {
        await improve();
      });
      return false;
    }
  }

  /// Back to the upload step to check another resume.
  void reset() {
    if (state.busy) return;
    _retry = null;
    state = const ResumeCheckState();
  }

  void _fail(
    Object error,
    ResumeCheckPhase backTo,
    Future<void> Function() retry,
  ) {
    if (!mounted) return;
    _retry = retry;
    state = state.copyWith(
      phase: ResumeCheckPhase.error,
      errorMessage: error.toString().replaceAll('Exception: ', ''),
      phaseBeforeError: backTo,
    );
  }

  Future<void> retry() async {
    final retry = _retry;
    final backTo = state.phaseBeforeError;
    if (state.phase != ResumeCheckPhase.error ||
        retry == null ||
        backTo == null) {
      return;
    }
    _retry = null;
    state = state.copyWith(phase: backTo);
    await retry();
  }

  /// Leave the error screen without retrying.
  void dismissError() {
    final backTo = state.phaseBeforeError;
    if (state.phase != ResumeCheckPhase.error || backTo == null) return;
    _retry = null;
    state = state.copyWith(phase: backTo);
  }
}

final resumeCheckProvider =
    StateNotifierProvider.autoDispose<ResumeCheckNotifier, ResumeCheckState>((
      ref,
    ) {
      return ResumeCheckNotifier(
        ref.watch(resumeRepositoryProvider),
        ref.read(currentUserUidProvider),
      );
    });
