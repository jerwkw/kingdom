import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

final authInstanceProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreInstanceProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// Base Backend URL (defaults to relative '/api' on Web for Firebase Hosting rewrite)
final backendBaseUrlProvider = StateProvider<String>((ref) => kIsWeb ? '/api' : 'http://localhost:5001');
final piServerBaseUrlProvider = backendBaseUrlProvider;

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authInstanceProvider).authStateChanges();
});

final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(authStateProvider).value ?? ref.watch(authInstanceProvider).currentUser;
  if (authUser == null) return Stream.value(null);

  final firestore = ref.watch(firestoreInstanceProvider);
  return firestore.collection('users').doc(authUser.uid).snapshots().map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.id, doc.data()!);
  });
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Ref _ref;

  AuthNotifier(this._auth, this._firestore, this._ref) : super(const AsyncValue.data(null));

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      if (kIsWeb) {
        try {
          final GoogleAuthProvider googleProvider = GoogleAuthProvider();
          googleProvider.addScope('email');
          googleProvider.addScope('profile');
          await _auth.signInWithPopup(googleProvider);
        } catch (webAuthErr) {
          debugPrint('[Auth Web Notice]: signInWithPopup failed ($webAuthErr). Using emulator fallback sign-in...');
          if (_auth.currentUser == null) {
            await _auth.signInAnonymously();
          }
        }
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          state = const AsyncValue.data(null);
          return;
        }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(credential);
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> completeOnboarding({
    required String name,
    required String role,
    required Map<String, String> avatarConfig,
    required String smartGoalText,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      state = AsyncValue.error('User not authenticated', StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final batch = _firestore.batch();

      // Create user document
      final userRef = _firestore.collection('users').doc(user.uid);
      batch.set(userRef, {
        'name': name.trim(),
        'role': role,
        'buildingId': null, // No initial building; user can create or join one
        'fishBalance': 10, // Starter bonus
        'avatarConfig': avatarConfig,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create required onboarding SMART Goal
      final goalRef = _firestore.collection('goals').doc();
      batch.set(goalRef, {
        'userId': user.uid,
        'type': 'smart',
        'task': 'Personal Spiritual Goal',
        'text': smartGoalText.trim(),
        'frequency': 'daily',
        'currentStreak': 0,
        'sharedToBulletin': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      _ref.invalidate(userProfileProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(
    ref.watch(authInstanceProvider),
    ref.watch(firestoreInstanceProvider),
    ref,
  );
});
