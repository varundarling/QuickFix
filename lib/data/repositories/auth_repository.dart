import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../core/services/firebase_service.dart';

class AuthRepository {
  final FirebaseService _firebaseService = FirebaseService.instance;

  Stream<User?> get authStateChanges =>
      _firebaseService.auth.authStateChanges();

  Future<UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      return await _firebaseService.signInWithEmailPassword(email, password);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      return await _firebaseService.signUpWithEmailPassword(email, password);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseService.signOut();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _firebaseService.auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _firebaseService.auth.currentUser;
      if (user != null) {
        final doc = await _firebaseService.getDocument('users', user.uid);
        if (doc.exists) {
          return UserModel.fromRealtimeDatabase(doc as Map);
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createUserProfile(UserModel userModel) async {
    try {
      await _firebaseService.createDocument(
        'users',
        userModel.id,
        userModel.toRealtimeDatabase(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserProfile(UserModel userModel) async {
    try {
      await _firebaseService.updateDocument(
        'users',
        userModel.id,
        userModel.toRealtimeDatabase(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> checkEmailExists(String email) async {
    try {
      final querySnapshot = await _firebaseService.getCollection(
        'users',
        queryBuilder: (query) => query.where('email', isEqualTo: email),
      );
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateFCMToken(String userId, String token) async {
    try {
      await _firebaseService.updateDocument('users', userId, {
        'fcmToken': token,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      // Delete user document
      await _firebaseService.firestore.collection('users').doc(userId).delete();

      // Delete user authentication
      await _firebaseService.auth.currentUser?.delete();
    } catch (e) {
      rethrow;
    }
  }
}
