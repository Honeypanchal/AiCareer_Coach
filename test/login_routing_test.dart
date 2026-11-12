import 'dart:async';

import 'package:ai_career_coach/core/routes/app_routes.dart';
import 'package:ai_career_coach/core/theme/theme_controller.dart';
import 'package:ai_career_coach/features/auth/data/auth_repository.dart';
import 'package:ai_career_coach/features/auth/presentation/login_screen.dart';
import 'package:ai_career_coach/features/chat/data/chat_message.model.dart';
import 'package:ai_career_coach/features/chat/data/chat_repository.dart';
import 'package:ai_career_coach/features/home/presentation/main_scaffold.dart';
import 'package:ai_career_coach/features/profile/data/profile_repository.dart';
import 'package:ai_career_coach/features/profile/data/user_profile.dart';
import 'package:ai_career_coach/features/profile/presentation/onboarding_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'user-1';
  @override
  String? get displayName => 'Test User';
  @override
  String? get email => 'test@example.com';
  @override
  String? get photoURL => null;
}

class _FakeChatRepository extends Fake implements ChatRepository {
  @override
  Future<List<ChatMessage>> loadChatHistory(String uid) async => [];
}

void main() {
  testWidgets('existing user never sees onboarding while logging in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = StreamController<User?>.broadcast();
    final profile = StreamController<UserProfile?>.broadcast();
    addTearDown(auth.close);
    addTearDown(profile.close);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => auth.stream),
        userProfileProvider('user-1').overrideWith((ref) => profile.stream),
        chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) =>
              MaterialApp.router(routerConfig: ref.watch(routerProvider)),
        ),
      ),
    );

    auth.add(null);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LoginScreen), findsOneWidget);

    // Sign in: the profile has not arrived yet, so onboarding must not show.
    auth.add(_FakeUser());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(OnboardingScreen), findsNothing);
    }

    profile.add(
      const UserProfile(
        uid: 'user-1',
        name: 'Test User',
        email: 'test@example.com',
        onboardingCompleted: true,
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(OnboardingScreen), findsNothing);
    }
    expect(find.byType(MainScaffold), findsOneWidget);
  });

  testWidgets(
    'returning user goes straight to Home without waiting for Firestore',
    (tester) async {
      // This phone already saw this user finish onboarding.
      SharedPreferences.setMockInitialValues({'onboarded_user-1': true});
      final prefs = await SharedPreferences.getInstance();
      final profile = StreamController<UserProfile?>.broadcast();
      addTearDown(profile.close);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(_FakeUser())),
          // The profile never arrives (slow or no internet).
          userProfileProvider('user-1').overrideWith((ref) => profile.stream),
          chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) =>
                MaterialApp.router(routerConfig: ref.watch(routerProvider)),
          ),
        ),
      );

      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(OnboardingScreen), findsNothing);
      }
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MainScaffold), findsOneWidget);

      // Back on another tab returns to Home instead of leaving the app.
      container.read(bottomNavIndexProvider.notifier).state = 2;
      await tester.pump();
      final handled = await tester.binding.handlePopRoute();
      await tester.pump();
      expect(handled, isTrue);
      expect(container.read(bottomNavIndexProvider), 0);
    },
  );
}
