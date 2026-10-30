import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/forgot_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/home/presentation/main_scaffold.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/about_screen.dart';
import '../../features/profile/presentation/appearance_screen.dart';
import '../../features/profile/presentation/change_password_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/history_placeholder_screen.dart';
import '../../features/profile/presentation/onboarding_screen.dart';

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
  static const resumeHistory = '/resume-history';
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
          child: const HistoryPlaceholderScreen(
            title: 'Interview history',
            subtitle:
                'Completed mock interviews will show up here in the interview step.',
            icon: Icons.mic_none_rounded,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.resumeHistory,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const HistoryPlaceholderScreen(
            title: 'Resume history',
            subtitle:
                'Scored resumes will show up here once Resume Check is built.',
            icon: Icons.description_outlined,
          ),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

class _AuthNotifier extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isAuthLoading = true;
  bool _isProfileLoading = true;
  bool _onboardingCompleted = false;
  bool _splashMinTimePassed = false;
  bool _wasLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isAuthLoading => _isAuthLoading;
  bool get isProfileLoading => _isProfileLoading;
  bool get onboardingCompleted => _onboardingCompleted;
  bool get splashMinTimePassed => _splashMinTimePassed;

  _AuthNotifier(Ref ref) {
    Future.delayed(const Duration(milliseconds: 2200), () {
      _splashMinTimePassed = true;
      notifyListeners();
    });

    ref.listen(authStateProvider, (previous, next) {
      _isAuthLoading = next.isLoading && !next.hasValue;
      _isLoggedIn = next.valueOrNull != null;

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
        _onboardingCompleted = next.valueOrNull?.onboardingCompleted ?? false;
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
