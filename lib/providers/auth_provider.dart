// providers/auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/journal_provider.dart'; // For chatProvider
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final authProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  return AuthNotifier(ref);
});

// providers/auth_provider.dart
class AuthNotifier extends StateNotifier<User?> {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  AuthNotifier(this._ref) : super(FirebaseAuth.instance.currentUser) {
    // Initialize with current user
    FirebaseAuth.instance.authStateChanges().listen((user) {
      state = user;
      if (user != null && user.emailVerified) {
        _ref.read(chatProvider.notifier).fetchInitialMessages(user.uid);
        _saveFCMToken(user.uid);
      } else {
        _ref.read(chatProvider.notifier).clearMessages();
      }
    });
  }

  // Add this new method to save FCM token
  Future<void> _saveFCMToken(String userId) async {
    try {
      print('Attempting to get FCM token...');
      final token = await _fcm.getToken();
      print('FCM Token retrieved: ${token ?? "NULL"}');

      if (token != null) {
        print('Saving token to Firestore for user $userId');
        await _firestore.collection('users').doc(userId).set(
          {'fcmToken': token},
          SetOptions(merge: true),
        );
        print('FCM Token saved successfully');

        // Verify the save by reading back
        final doc = await _firestore.collection('users').doc(userId).get();
        print('Verified Firestore data: ${doc.data()}');
      } else {
        print('FCM Token was null, not saving');
      }
    } catch (e, stack) {
      print('Error saving FCM token: $e');
      print('Stack trace: $stack');
    }
  }

  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ✅ Directly call it here
      await _saveFCMToken(cred.user!.uid);

      return cred;
    } on FirebaseAuthException catch (e) {
      throw authExceptionHandler(e);
    }
  }

  Future<UserCredential> signUpWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        return userCredential;
      }
      throw FirebaseAuthException(code: 'user-not-created', message: 'User creation failed');
    } on FirebaseAuthException catch (e) {
      print('SIGNUP ERROR: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw authExceptionHandler(e);
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await state?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw authExceptionHandler(e);
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  String authExceptionHandler(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No account found for this email';
      case 'invalid-credential':
        return 'Incorrect email and/or password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled';
      case 'weak-password':
        return 'Password is too weak (min 6 characters)';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'requires-recent-login':
        return 'Session expired. Please log in again';
      default:
        return 'Incorrect credentials: ${e.message}';
    }
  }
}