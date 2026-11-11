import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/app_firestore.dart';
import '../../auth/data/auth_repository.dart';
import 'user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

/// Live profile for a given uid. Screens should pass uid explicitly
/// so there is no race with auth restoring.
final userProfileProvider =
    StreamProvider.family<UserProfile?, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).watchProfile(uid);
});

/// Convenience: current signed-in user's profile (null if logged out).
final currentUserProfileProvider = Provider<AsyncValue<UserProfile?>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return const AsyncValue.data(null);
  }
  return ref.watch(userProfileProvider(uid));
});

class ProfileRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseFirestore get _firestore => appFirestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Stream<UserProfile?> watchProfile(String uid) {
    // An empty phone cache (new install, other device) answers "no document"
    // before the server replies. Skip that answer so a returning user isn't
    // sent to onboarding; wait for the server instead.
    return _userDoc(uid)
        .snapshots()
        .where((snap) => snap.exists || !snap.metadata.isFromCache)
        .map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromMap(uid, snap.data());
    });
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    String? headline,
    String? location,
    String? targetRole,
    String? experienceLevel,
    List<String>? skills,
    bool? onboardingCompleted,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) data['name'] = name.trim();
    if (headline != null) data['headline'] = headline.trim();
    if (location != null) data['location'] = location.trim();
    if (targetRole != null) data['targetRole'] = targetRole.trim();
    if (experienceLevel != null) data['experienceLevel'] = experienceLevel;
    if (skills != null) data['skills'] = skills;
    if (onboardingCompleted != null) {
      data['onboardingCompleted'] = onboardingCompleted;
    }

    await _userDoc(uid).set(data, SetOptions(merge: true));

    if (name != null && name.trim().isNotEmpty) {
      await _auth.currentUser?.updateDisplayName(name.trim());
    }
  }

  Future<String> uploadAvatar({
    required String uid,
    required File file,
  }) async {
    final ref = _storage.ref().child('users/$uid/avatar.jpg');
    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();

    await _userDoc(uid).set({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _auth.currentUser?.updatePhotoURL(url);
    return url;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

    final cred = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

    final cred = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(cred);

    final uid = user.uid;

    try {
      await _storage.ref().child('users/$uid/avatar.jpg').delete();
    } catch (_) {
      // Avatar may not exist yet.
    }

    await _deleteSubcollection(uid, 'chat_messages');
    await _deleteSubcollection(uid, 'chats');
    await _deleteSubcollection(uid, 'resumes');
    await _deleteSubcollection(uid, 'interviews');
    await _userDoc(uid).delete();
    await user.delete();
  }

  Future<void> _deleteSubcollection(String uid, String name) async {
    final col = _userDoc(uid).collection(name);
    while (true) {
      final snap = await col.limit(300).get();
      if (snap.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
