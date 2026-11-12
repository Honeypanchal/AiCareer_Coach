// debugState is the way to read a StateNotifier's state from a test.
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_career_coach/core/ai/gemini_client.dart';
import 'package:ai_career_coach/features/resume/data/resume_models.dart';
import 'package:ai_career_coach/features/resume/data/resume_pdf.dart';
import 'package:ai_career_coach/features/resume/data/resume_repository.dart';
import 'package:ai_career_coach/features/resume/presentation/resume_check_controller.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _analysisJson({bool isResume = true}) => {
  'isResume': isResume,
  'resumeText': 'Asha Rao asha@example.com Flutter Dart',
  'categories': {
    'formatting': {'score': 8, 'comment': 'Clean'},
    'impact': {'score': 4, 'comment': 'Duties only'},
    'relevance': {'score': 7, 'comment': 'Good match'},
    'clarity': {'score': 6, 'comment': 'OK'},
    'completeness': {'score': 5, 'comment': 'No links'},
  },
  'summary': 'Decent start.',
  'strengths': ['Clear layout'],
  'improvements': [
    {
      'priority': 'low',
      'section': 'Hobbies',
      'issue': 'Not needed',
      'suggestion': 'Remove',
    },
    {
      'priority': 'high',
      'section': 'Projects',
      'issue': 'No results',
      'suggestion': 'Show impact',
    },
  ],
  'missingKeywords': ['Git'],
};

ResumeAnalysis _analysis() => parseAnalysis(
  _analysisJson(),
  fileName: 'cv.pdf',
  targetRole: 'Flutter Developer',
  usedJobDescription: false,
);

class _FakeResumeRepository extends Fake implements ResumeRepository {
  Object? failAnalyze;
  int improveCalls = 0;

  @override
  Future<ResumeAnalysis> analyze({
    required List<int> pdfBytes,
    required String fileName,
    required String targetRole,
    String experienceLevel = '',
    String jobDescription = '',
  }) async {
    if (failAnalyze != null) {
      final error = failAnalyze!;
      failAnalyze = null;
      throw error;
    }
    return _analysis();
  }

  @override
  Future<ImprovedResume> improve({
    required List<int> pdfBytes,
    required ResumeAnalysis analysis,
    String jobDescription = '',
  }) async {
    improveCalls++;
    return const ImprovedResume(name: 'Asha Rao');
  }

  @override
  Future<String> saveAnalysis(String uid, ResumeAnalysis analysis) async =>
      'doc-1';

  @override
  Future<void> saveImprovedResume(
    String uid,
    String id,
    ImprovedResume resume,
  ) async {}
}

final _pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.7 test'));

void main() {
  group('parseAnalysis', () {
    test('overall score is the weighted average of the categories', () {
      // (8*20 + 4*25 + 7*25 + 6*15 + 5*15) / 100 * 10 = 60
      expect(_analysis().overallScore, 60);
    });

    test('improvements are sorted with high priority first', () {
      expect(_analysis().improvements.map((i) => i.priority), [
        ImprovementPriority.high,
        ImprovementPriority.low,
      ]);
    });

    test('keeps the original text for the accuracy check', () {
      expect(_analysis().originalText, contains('asha@example.com'));
    });

    test('a document that is not a resume is rejected', () {
      expect(
        () => parseAnalysis(
          _analysisJson(isResume: false),
          fileName: 'x.pdf',
          targetRole: '',
          usedJobDescription: false,
        ),
        throwsA(
          isA<GeminiException>()
              .having(
                (e) => e.message,
                'message',
                contains("doesn't look like a resume"),
              )
              .having((e) => e.retryable, 'retryable', isFalse),
        ),
      );
    });

    test('a review with missing categories can be retried', () {
      final json = _analysisJson()
        ..['categories'] = {
          'formatting': {'score': 5},
        };
      expect(
        () => parseAnalysis(
          json,
          fileName: 'x.pdf',
          targetRole: '',
          usedJobDescription: false,
        ),
        throwsA(
          isA<GeminiException>().having(
            (e) => e.retryable,
            'retryable',
            isTrue,
          ),
        ),
      );
    });
  });

  group('verifyAgainstOriginal', () {
    const original = '''Asha Rao
asha.rao@example.com | +91 98765 43210 | Pune, India | github.com/asharao
Skills: Flutter, Dart, Firebase
Built a shopping app used by 200 students.''';

    const rewritten = ImprovedResume(
      name: 'Asha Rao',
      contact: [
        'asha.rao@example.com',
        '+91 9876543210',
        'Pune, India',
        'https://github.com/asharao',
        'linkedin.com/in/asharao',
      ],
      skills: [
        ResumeListSection(title: 'Mobile', items: ['Flutter', 'Dart', 'Bloc']),
        ResumeListSection(title: 'Cloud', items: ['AWS']),
      ],
      projects: [
        ResumeEntry(
          title: 'Shopping App',
          bullets: [
            'Built a shopping app used by 200 students.',
            'Cut load time by 40% with caching.',
          ],
        ),
      ],
    );

    final checked = verifyAgainstOriginal(rewritten, original);

    test('keeps real contact details even when formatted differently', () {
      expect(checked.contact, [
        'asha.rao@example.com',
        '+91 9876543210',
        'Pune, India',
        'https://github.com/asharao',
      ]);
    });

    test('removes invented skills and empty groups', () {
      expect(checked.skills.single.items, ['Flutter', 'Dart']);
    });

    test('removes bullets with numbers that are not in the original', () {
      expect(checked.projects.single.bullets, [
        'Built a shopping app used by 200 students.',
      ]);
    });

    test('explains every removal in the tips', () {
      final tips = checked.tips.join('\n');
      expect(tips, contains('linkedin.com/in/asharao'));
      expect(tips, contains('Bloc'));
      expect(tips, contains('40%'));
    });

    test('does nothing when the original text is unknown', () {
      expect(verifyAgainstOriginal(rewritten, '').contact, hasLength(5));
    });
  });

  group('PDF', () {
    test('builds a PDF with the built-in font', () async {
      final bytes = await buildResumePdf(
        const ImprovedResume(
          name: 'Asha Rao',
          headline: 'Flutter Developer',
          contact: ['asha@example.com'],
          summary: 'Builds apps – fast “and” clean.',
          skills: [
            ResumeListSection(title: 'Mobile', items: ['Flutter']),
          ],
          projects: [
            ResumeEntry(
              title: 'App',
              period: 'Jan 2024 – Present',
              bullets: ['Did a thing'],
            ),
          ],
          education: [ResumeEntry(title: 'B.E.', organization: 'College')],
          extraSections: [
            ResumeListSection(title: 'Awards', items: ['Hackathon winner']),
          ],
        ),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('latinSafe swaps characters Helvetica cannot draw', () {
      expect(
        latinSafe('Jan – Present “ok” ₹5 • 日本'),
        'Jan - Present "ok" Rs.5 - ',
      );
      expect(latinSafe('Café'), 'Café');
    });
  });

  group('models', () {
    test('analysis survives a save and load round trip', () {
      final saved = _analysis().copyWith(
        id: 'a1',
        improvedResume: const ImprovedResume(
          name: 'Asha Rao',
          contact: ['asha@example.com'],
          experience: [
            ResumeEntry(
              title: 'Intern',
              organization: 'Acme',
              bullets: ['Built X'],
            ),
          ],
          tips: ['Add a link'],
        ),
      );
      final map = saved.toMap();
      expect(map.containsKey('originalText'), isFalse);

      final loaded = ResumeAnalysis.fromMap('a1', map);
      expect(loaded.overallScore, 60);
      expect(loaded.categories, hasLength(5));
      expect(loaded.improvements.first.priority, ImprovementPriority.high);
      expect(loaded.improvedResume!.experience.single.organization, 'Acme');
      expect(loaded.improvedResume!.tips, ['Add a link']);
    });
  });

  group('ResumeCheckNotifier', () {
    test('rejects files that are not PDFs', () {
      final notifier = ResumeCheckNotifier(_FakeResumeRepository(), 'u1');
      notifier.setFile('cv.docx', Uint8List.fromList([0x50, 0x4B, 3, 4, 5, 6]));
      expect(notifier.debugState.file, isNull);
      expect(notifier.debugState.fileError, contains('PDF'));
    });

    test('analyzes, saves, then improves once', () async {
      final repo = _FakeResumeRepository();
      final notifier = ResumeCheckNotifier(repo, 'u1');
      notifier.setFile('cv.pdf', _pdfBytes);

      await notifier.analyze(targetRole: 'Flutter Developer');
      expect(notifier.debugState.phase, ResumeCheckPhase.result);
      expect(notifier.debugState.saved, isTrue);
      expect(notifier.debugState.analysis!.id, 'doc-1');

      expect(await notifier.improve(), isTrue);
      expect(await notifier.improve(), isTrue);
      expect(repo.improveCalls, 1);
      expect(notifier.debugState.analysis!.improvedResume!.name, 'Asha Rao');
    });

    test('an error can be retried and keeps the file', () async {
      final repo = _FakeResumeRepository()
        ..failAnalyze = const GeminiException('Gemini is busy');
      final notifier = ResumeCheckNotifier(repo, 'u1');
      notifier.setFile('cv.pdf', _pdfBytes);

      await notifier.analyze(targetRole: '');
      expect(notifier.debugState.phase, ResumeCheckPhase.error);
      expect(notifier.debugState.file, isNotNull);

      await notifier.retry();
      expect(notifier.debugState.phase, ResumeCheckPhase.result);
    });

    test('going back from an error returns to upload', () async {
      final repo = _FakeResumeRepository()
        ..failAnalyze = const GeminiException(
          "This file doesn't look like a resume.",
        );
      final notifier = ResumeCheckNotifier(repo, 'u1');
      notifier.setFile('cv.pdf', _pdfBytes);

      await notifier.analyze(targetRole: '');
      notifier.dismissError();
      expect(notifier.debugState.phase, ResumeCheckPhase.idle);
    });
  });
}
