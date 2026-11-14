// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders the main screens with sample data to PNG files, for design review.
//
//   flutter test tool/screens/render_screens_test.dart
//
// Output goes to build/screens/ (or SCREENS_OUT). No Firebase or Gemini calls:
// every data source is replaced with a fake. Lives in tool/ so the normal
// `flutter test` run skips it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_career_coach/core/theme/app_theme.dart';
import 'package:ai_career_coach/core/theme/theme_controller.dart';
import 'package:ai_career_coach/features/auth/data/auth_repository.dart';
import 'package:ai_career_coach/features/auth/presentation/login_screen.dart';
import 'package:ai_career_coach/features/chat/data/chat_message.model.dart';
import 'package:ai_career_coach/features/chat/data/chat_repository.dart';
import 'package:ai_career_coach/features/home/presentation/main_scaffold.dart';
import 'package:ai_career_coach/features/interview/data/interview_models.dart';
import 'package:ai_career_coach/features/interview/data/interview_repository.dart';
import 'package:ai_career_coach/features/interview/data/voice_answer.dart';
import 'package:ai_career_coach/features/interview/presentation/interview_report_screen.dart';
import 'package:ai_career_coach/features/interview/presentation/interview_session_screen.dart';
import 'package:ai_career_coach/features/auth/presentation/signup_screen.dart';
import 'package:ai_career_coach/features/resume/presentation/resume_history_screen.dart';
import 'package:ai_career_coach/features/profile/data/profile_repository.dart';
import 'package:ai_career_coach/features/profile/data/user_profile.dart';
import 'package:ai_career_coach/features/resume/data/resume_models.dart';
import 'package:ai_career_coach/features/resume/data/resume_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────
class _User extends Fake implements User {
  @override
  String get uid => 'u1';
  @override
  String? get displayName => 'Honey Panchal';
  @override
  String? get email => 'honey@example.com';
  @override
  String? get photoURL => null;
}

const _profile = UserProfile(
  uid: 'u1',
  name: 'Honey Panchal',
  email: 'honey@example.com',
  headline: 'Flutter Developer · 1.5 yrs',
  location: 'Ahmedabad, India',
  targetRole: 'Flutter Developer',
  experienceLevel: '1-2 years',
  skills: ['Flutter', 'Dart', 'Firebase', 'Riverpod', 'REST APIs'],
  onboardingCompleted: true,
);

class _Chat extends Fake implements ChatRepository {
  @override
  Future<List<ChatMessage>> loadChatHistory(String uid) async => [
    ChatMessage(
      text: 'How should I prepare for a Flutter interview?',
      isUser: true,
    ),
    ChatMessage(
      text:
          'Great question! Focus on these areas:\n\n'
          '1. **Widgets & state**: StatelessWidget vs StatefulWidget, setState\n'
          '2. **State management**: Riverpod or Bloc, and *why* you chose it\n'
          '3. **Async**: Futures, Streams, `async/await`\n\n'
          'Want a quick mock question?',
      isUser: false,
    ),
    ChatMessage(text: 'Yes, ask me one!', isUser: true),
  ];
}

InterviewTurn _turn(String q, int score) => InterviewTurn(
  question: q,
  isFollowUp: false,
  answer: 'A widget that keeps state in a separate State object.',
  skipped: false,
  score: score,
  good: const ['Explained the State object', 'Mentioned setState'],
  missing: const ['Widget itself stays immutable'],
  modelAnswer:
      'A **StatefulWidget** is immutable; its mutable state lives in a `State` object…',
  byVoice: true,
  delivery: const VoiceDelivery(
    fillerWords: 3,
    pace: SpeakingPace.good,
    tips: ['Pause instead of saying "um"', 'Lead with the definition'],
  ),
);

InterviewSession _session(String topic, int score, int daysAgo) =>
    InterviewSession(
      id: topic,
      topic: topic,
      difficulty: InterviewDifficulty.medium,
      createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
      turns: [_turn('What is a StatefulWidget?', score ~/ 10)],
      report: InterviewReport(
        overallScore: score,
        summary: 'Solid fundamentals; go deeper on state management.',
        strongAreas: const ['Widgets'],
        weakAreas: const ['State management'],
        practiceNext: const ['Riverpod providers'],
      ),
    );

class _Interviews extends Fake implements InterviewRepository {
  @override
  Future<String> firstQuestion(InterviewConfig config) async =>
      'Explain the difference between a StatelessWidget and a StatefulWidget. When would you use each?';

  @override
  Future<AnswerEvaluation> evaluateAnswer({
    required InterviewConfig config,
    required List<InterviewTurn> previousTurns,
    required String question,
    required bool isFollowUp,
    required String answer,
    required bool skipped,
    required bool wantNextQuestion,
    VoiceAnswer? voice,
  }) async => const AnswerEvaluation(
    score: 7,
    good: ['Explained the State object', 'Mentioned setState'],
    missing: [
      'Widget itself stays immutable',
      'Lifecycle: initState / dispose',
    ],
    modelAnswer:
        'A **StatelessWidget** never changes after it is built. A **StatefulWidget** is still immutable, but it creates a `State` object that holds data which can change; calling `setState` rebuilds it.',
    nextQuestion: 'What does BuildContext represent?',
    transcript:
        'Um, so a stateless widget cannot change, and a stateful widget has a State object, and when you call setState, like, it rebuilds.',
    delivery: VoiceDelivery(
      fillerWords: 2,
      pace: SpeakingPace.good,
      tips: ['Pause instead of saying "um"', 'Give a quick example'],
    ),
  );
}

ResumeAnalysis _analysis() => parseAnalysis(
  {
    'isResume': true,
    'resumeText': 'Honey Panchal',
    'categories': {
      'formatting': {'score': 8, 'comment': 'Clean, single-column layout.'},
      'impact': {'score': 5, 'comment': 'Bullets list duties, not results.'},
      'relevance': {'score': 8, 'comment': 'Strong Flutter focus.'},
      'clarity': {'score': 7, 'comment': 'Mostly concise.'},
      'completeness': {'score': 6, 'comment': 'No GitHub link.'},
    },
    'summary': 'A solid Flutter resume that needs measurable results.',
    'strengths': ['Relevant Flutter projects', 'Clean layout'],
    'improvements': [
      {
        'priority': 'high',
        'section': 'Experience',
        'issue': 'No numbers',
        'suggestion': 'Add impact, e.g. users or speed.',
      },
      {
        'priority': 'medium',
        'section': 'Links',
        'issue': 'No GitHub',
        'suggestion': 'Add your GitHub profile.',
      },
    ],
    'missingKeywords': ['CI/CD', 'Unit testing'],
  },
  fileName: 'Honey_Resume.pdf',
  targetRole: 'Flutter Developer',
  usedJobDescription: false,
);

// ── Fonts ────────────────────────────────────────────────────────────────────
Future<void> _loadFonts() async {
  final sdk = File(Platform.resolvedExecutable)
      .parent
      .parent
      .parent
      .parent
      .parent
      .parent
      .path; // …/flutter/bin/cache/dart-sdk/bin/dart → …/flutter
  final materialFonts = '$sdk/bin/cache/artifacts/material_fonts';

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File(f);
      if (file.existsSync()) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    await loader.load();
  }

  await load('MaterialIcons', ['$materialFonts/materialicons-regular.otf']);
  await load('Roboto', [
    for (final w in ['regular', 'medium', 'bold', 'italic'])
      '$materialFonts/roboto-$w.ttf',
  ]);
  // The app's own fonts, if it declares any in assets/fonts/.
  final fontsDir = Directory('assets/fonts');
  if (fontsDir.existsSync()) {
    final byFamily = <String, List<String>>{};
    for (final f in fontsDir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (!name.endsWith('.ttf')) continue;
      byFamily.putIfAbsent(name.split('-').first, () => []).add(f.path);
    }
    for (final e in byFamily.entries) {
      await load(e.key, e.value);
    }
  }
}

// ── Rendering ────────────────────────────────────────────────────────────────
final _out = Platform.environment['SCREENS_OUT'] ?? 'build/screens';

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget Function() screen, {
  ThemeMode mode = ThemeMode.dark,
  int tab = 0,
  Future<void> Function(WidgetTester)? interact,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith((ref) => Stream.value(_User())),
      userProfileProvider('u1').overrideWith((ref) => Stream.value(_profile)),
      chatRepositoryProvider.overrideWithValue(_Chat()),
      interviewRepositoryProvider.overrideWithValue(_Interviews()),
      interviewHistoryProvider.overrideWith(
        (ref) => Stream.value([
          _session('Flutter', 72, 0),
          _session('Dart', 85, 2),
          _session('HR / Behavioural', 64, 5),
        ]),
      ),
      resumeHistoryProvider.overrideWith((ref) => Stream.value([_analysis()])),
    ],
  );
  container.read(bottomNavIndexProvider.notifier).state = tab;

  final key = GlobalKey();
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => screen())],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: key,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          routerConfig: router,
        ),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (interact != null) await interact(tester);
  await tester.pump(const Duration(seconds: 1));

  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });

  await tester.pumpWidget(const SizedBox());
  container.dispose();
}

void main() {
  setUpAll(_loadFonts);

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('screens', (tester) async {
    await phone(tester);
    // Tests draw shadows without blur unless this is turned off; the test
    // framework expects it back on when the test ends.
    debugDisableShadows = false;
    try {
      await _allShots(tester);
    } finally {
      debugDisableShadows = true;
    }
  });
}

Future<void> _allShots(WidgetTester tester) async {
  const config = InterviewConfig(
    topic: 'Flutter',
    difficulty: InterviewDifficulty.medium,
    questionCount: 5,
  );
  {
    await _shot(tester, '01_home_dark', () => const MainScaffold());
    await _shot(
      tester,
      '02_home_light',
      () => const MainScaffold(),
      mode: ThemeMode.light,
    );
    await _shot(tester, '03_chat', () => const MainScaffold(), tab: 1);
    await _shot(tester, '04_interview_tab', () => const MainScaffold(), tab: 2);
    await _shot(tester, '05_resume_tab', () => const MainScaffold(), tab: 3);
    await _shot(tester, '06_profile', () => const MainScaffold(), tab: 4);
    await _shot(tester, '07_login', () => const LoginScreen());
    await _shot(
      tester,
      '08_session_question',
      () => const InterviewSessionScreen(config: config),
      interact: (t) async {
        await t.tap(find.text('Speak'));
        await t.pump();
      },
    );
    await _shot(
      tester,
      '09_session_feedback',
      () => const InterviewSessionScreen(config: config),
      interact: (t) async {
        await t.enterText(find.byType(TextField), 'My answer');
        await t.pump();
        await t.tap(find.text('Submit answer'));
        for (var i = 0; i < 5; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      },
    );
    await _shot(
      tester,
      '10_interview_report',
      () => InterviewReportScreen(session: _session('Flutter', 72, 0)),
    );
    await _shot(tester, '11_signup', () => const SignupScreen());
    await _shot(tester, '12_resume_history', () => const ResumeHistoryScreen());
    await _shot(
      tester,
      '13_resume_report',
      () => ResumeReportScreen(analysis: _analysis()),
      mode: ThemeMode.light,
    );
  }
}
