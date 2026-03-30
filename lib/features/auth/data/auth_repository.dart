import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;
  static bool get hasUser => currentUser != null;
  static bool get isAnonymous => currentUser?.isAnonymous == true;

  static Future<User?> signInSilently() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        return currentUser;
      }
      final userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      if (kDebugMode) debugPrint('Error in signInSilently: $e');
      return null;
    }
  }

  static Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        final userCredential = await currentUser.linkWithCredential(credential);
        return userCredential.user;
      } else {
        final userCredential = await _auth.signInWithCredential(credential);
        return userCredential.user;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error in signInWithGoogle: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final db = FirebaseFirestore.instance;

    try {
      // 1. Clean up Firestore data
      final batch = db.batch();

      // Delete daily_logs
      final logs = await db.collection('users').doc(uid).collection('daily_logs').get();
      for (final doc in logs.docs) {
        batch.delete(doc.reference);
      }

      // Delete emergency_contacts
      final contacts =
          await db.collection('users').doc(uid).collection('emergency_contacts').get();
      for (final doc in contacts.docs) {
        batch.delete(doc.reference);
      }

      // Delete sos_events
      final sosEvents =
          await db.collection('users').doc(uid).collection('sos_events').get();
      for (final doc in sosEvents.docs) {
        batch.delete(doc.reference);
      }

      // Delete main user document
      batch.delete(db.collection('users').doc(uid));

      // 2. Delete Auth user first (may throw requires-recent-login)
      await user.delete();
      await _googleSignIn.signOut();

      // 3. Only delete Firestore data after Auth deletion succeeds
      await batch.commit();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (kDebugMode) debugPrint('[AuthRepo] Re-authentication required for deletion.');
        rethrow;
      }
      if (kDebugMode) debugPrint('[AuthRepo] Error deleting account: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthRepo] Error deleting account: $e');
      rethrow;
    }
  }
}
