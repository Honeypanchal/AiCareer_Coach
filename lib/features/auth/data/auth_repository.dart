import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/app_firestore.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseFirestore get _firestore => appFirestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Sign Up ────────────────────────────────────────────────────────────────
  // Returns uid so the screen can invalidate userProfileProvider after signup
  Future<String> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    // Step 1: Create Firebase Auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user!;

    // Step 2: Set displayName on Auth profile
    await user.updateDisplayName(name);
    await user.reload();

    final uid = user.uid;
    debugPrint('✅ Auth created: uid=$uid name=$name');

    // Step 3: Create the profile document. This also creates the "users"
    // collection the first time; nothing has to be made by hand.
    // Firestore keeps the write in its local queue and syncs it, so a slow
    // network must not keep the user stuck on the sign-up screen.
    await _firestore
        .collection('users')
        .doc(uid)
        .set({
          'uid': uid,
          'name': name,
          'email': email,
          'photoUrl': '',
          'headline': '',
          'location': '',
          'targetRole': '',
          'experienceLevel': '',
          'skills': <String>[],
          'onboardingCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 10), onTimeout: () {
          debugPrint('Profile write still syncing for uid=$uid');
        });

    debugPrint('✅ Firestore write done for uid=$uid');
    return uid;
  }

  // ── Sign In ────────────────────────────────────────────────────────────────
  // Returns uid so the screen can invalidate userProfileProvider after login
  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user!;
    debugPrint('✅ Signed in: uid=${user.uid}');

    // Runs in the background: login must not wait on Firestore.
    ensureUserDocument(user).catchError((Object e) {
      debugPrint('Could not update the profile document: $e');
    });

    return user.uid;
  }

  /// Makes sure `users/{uid}` exists and records the login time.
  ///
  /// If the document is missing (for example the sign-up write never reached
  /// Firebase) it is created again from the Auth account, so the user gets a
  /// profile instead of a broken app.
  Future<void> ensureUserDocument(User user) async {
    final doc = _firestore.collection('users').doc(user.uid);
    final snap = await doc.get(const GetOptions(source: Source.server));

    if (!snap.exists) {
      await doc.set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'headline': '',
        'location': '',
        'targetRole': '',
        'experienceLevel': '',
        'skills': <String>[],
        'onboardingCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await doc.set({
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Restore displayName from Firestore if missing from Auth
    final savedName = snap.data()?['name'] as String?;
    if ((user.displayName ?? '').isEmpty &&
        savedName != null &&
        savedName.isNotEmpty) {
      await user.updateDisplayName(savedName);
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Password Reset ─────────────────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Get user profile ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      debugPrint('⚠️ No Firestore doc for uid=$uid');
      return null;
    }
    debugPrint('✅ Got profile: ${doc.data()}');
    return doc.data();
  }
}

// ── Auth error messages ────────────────────────────────────────────────────────
String getAuthErrorMessage(String code) {
  switch (code) {
    case 'email-already-in-use':
      return 'This email is already registered. Try logging in.';
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'weak-password':
      return 'Password must be at least 6 characters.';
    case 'user-not-found':
      return 'No account found with this email.';
    case 'wrong-password':
      return 'Incorrect password. Please try again.';
    case 'requires-recent-login':
      return 'Please sign in again, then retry this action.';
    case 'invalid-credential':
      return 'Incorrect email or password. Please try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'No internet connection.';
    default:
      return 'Something went wrong. Please try again.';
  }
}