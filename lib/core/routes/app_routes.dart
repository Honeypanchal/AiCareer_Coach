import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/forgot_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/home/presentation/main_scaffold.dart';
import '../../features/interview/data/interview_models.dart';
import '../../features/interview/presentation/interview_history_screen.dart';
import '../../features/interview/presentation/interview_report_screen.dart';
import '../../features/interview/presentation/interview_session_screen.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/about_screen.dart';
import '../../features/profile/presentation/appearance_screen.dart';
import '../../features/profile/presentation/change_password_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/onboarding_screen.dart';
import '../../features/resume/data/resume_models.dart';
import '../../features/resume/presentation/improved_resume_screen.dart';
import '../../features/resume/presentation/resume_check_screen.dart';
import '../../features/resume/presentation/resume_history_screen.dart';
import '../theme/theme_controller.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const onboarding = '/onboarding';
  static const editProfile = '/edit-profile';
  static const appearance = '/appearance';
  static const about = '/about';
  static const changePassword = '/change-password';
  static const interviewHistory = '/interview-history';
  static const interviewSession = '/interview/session';
  static const interviewReport = '/interview/report';
  static const resumeHistory = '/resume-history';
  static const resumeCheck = '/resume-check';
  static const improvedResume = '/resume-check/improved';
  static const resumeReport = '/resume-report';
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final location = state.matchedLocation;
      final isLoggedIn = notifier.isLoggedIn;
      final isAuthLoading = notifier.isAuthLoading;
      final splashReady = notifier.splashMinTimePassed;

      final isAuthRoute = location == AppRoutes.login ||
          location == AppRoutes.signup ||
          location == AppRoutes.forgotPassword ||
          location == AppRoutes.splash;
      final isOnboarding = location == AppRoutes.onboarding;

      // Keep the splash visible for the branded animation.
      if (location == AppRoutes.splash && (!splashReady || isAuthLoading)) {
        return null;
      }

      if (isAuthLoading) return null;

      if (!isLoggedIn) {
        if (location == AppRoutes.splash) return AppRoutes.login;
        if (!isAuthRoute) return AppRoutes.login;
        return null;
      }

      if (notifier.isProfileLoading) {
        return location == AppRoutes.splash ? null : null;
      }

      if (!notifier.onboardingCompleted) {
        if (!isOnboarding) return AppRoutes.onboarding;
        return null;
      }

      if (isAuthRoute || isOnboarding) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _fadeTransition(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signup,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const SignupScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const MainScaffold(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const EditProfileScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.appearance,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const AppearanceScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.about,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const AboutScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const ChangePasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.interviewHistory,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const InterviewHistoryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.interviewSession,
        pageBuilder: (context, state) {
          final config = state.extra;
          return _slideTransition(
            state: state,
            child: config is InterviewConfig
                ? InterviewSessionScreen(config: config)
                : const _MissingPage(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.interviewReport,
        pageBuilder: (context, state) {
          final session = state.extra;
          return _slideTransition(
            state: state,
            child: InterviewReportScreen(
              session: session is InterviewSession ? session : null,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.resumeHistory,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const ResumeHistoryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.resumeCheck,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const ResumeCheckScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.improvedResume,
        pageBuilder: (context, state) {
          final resume = state.extra;
          return _slideTransition(
            state: state,
            child: ImprovedResumeScreen(
              resume: resume is ImprovedResume ? resume : null,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.resumeReport,
        pageBuilder: (context, state) {
          final analysis = state.extra;
          return _slideTransition(
            state: state,
            child: ResumeReportScreen(
              analysis: analysis is ResumeAnalysis ? analysis : null,
            ),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

// Shown if a page that needs data from the previous screen is opened without
// it (for example after the app was restored by Android).
class _MissingPage extends StatelessWidget {
  const _MissingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('Please start again from the Interview tab.')),
    );
  }
}

class _AuthNotifier extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isAuthLoading = true;
  bool _isProfileLoading = true;
  bool _onboardingCompleted = false;
  bool _splashMinTimePassed = false;
  bool _wasLoggedIn = false;
  String? _uid;
  final SharedPreferences _prefs;

  bool get isLoggedIn => _isLoggedIn;
  bool get isAuthLoading => _isAuthLoading;
  // A user who finished onboarding on this phone goes straight to Home,
  // without waiting for the profile to load.
  bool get isProfileLoading => _isProfileLoading && !_rememberedOnboarding;
  bool get onboardingCompleted => _onboardingCompleted || _rememberedOnboarding;
  bool get splashMinTimePassed => _splashMinTimePassed;

  static String _onboardedKey(String uid) => 'onboarded_$uid';

  bool get _rememberedOnboarding {
    final uid = _uid;
    return uid != null && (_prefs.getBool(_onboardedKey(uid)) ?? false);
  }

  _AuthNotifier(Ref ref) : _prefs = ref.read(sharedPreferencesProvider) {
    Future.delayed(const Duration(milliseconds: 2200), () {
      _splashMinTimePassed = true;
      notifyListeners();
    });

    ref.listen(authStateProvider, (previous, next) {
      _isAuthLoading = next.isLoading && !next.hasValue;
      _isLoggedIn = next.valueOrNull != null;
      _uid = next.valueOrNull?.uid;

      if (_isLoggedIn && !_wasLoggedIn) {
        Future.microtask(() {
          ref.read(bottomNavIndexProvider.notifier).state = 0;
        });
      }

      _wasLoggedIn = _isLoggedIn;
      notifyListeners();
    }, fireImmediately: true);

    ref.listen(currentUserProfileProvider, (previous, next) {
      if (next.hasError) {
        // Don't trap the user on onboarding if Firestore is unavailable.
        _isProfileLoading = false;
        _onboardingCompleted = true;
      } else {
        _isProfileLoading = next.isLoading && !next.hasValue;
        final profile = next.valueOrNull;
        _onboardingCompleted = profile?.onboardingCompleted ?? false;
        if (profile != null && profile.onboardingCompleted) {
          _prefs.setBool(_onboardedKey(profile.uid), true);
        }
      }
      notifyListeners();
    }, fireImmediately: true);
  }
}

CustomTransitionPage _fadeTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

CustomTransitionPage _slideTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: animation.drive(tween), child: child),
      );
    },
  );
}
