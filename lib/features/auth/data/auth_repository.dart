import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    // Step 3: Write to Firestore
    // No try-catch here — let it throw so caller knows if it failed
    await _firestore.collection('users').doc(uid).set({
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
    final uid = user.uid;
    debugPrint('✅ Signed in: uid=$uid');

    // Update last login time
    await _firestore.collection('users').doc(uid).set({
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Restore displayName from Firestore if missing from Auth
    if (user.displayName == null || user.displayName!.isEmpty) {
      final doc = await _firestore.collection('users').doc(uid).get();
      final savedName = doc.data()?['name'] as String?;
      if (savedName != null && savedName.isNotEmpty) {
        await user.updateDisplayName(savedName);
        await user.reload();
        debugPrint('✅ Restored displayName: $savedName');
      }
    }

    return uid;
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