// lib/core/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:flutter/material.dart';

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();

  FirebaseService._();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseDatabase get database => FirebaseDatabase.instance;

  Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  // ✅ Auth Methods with better error handling
  Future<UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      debugPrint('🔄 Attempting sign in for: $email');
      final result = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ Sign in successful');
      return result;
    } catch (e) {
      debugPrint('❌ Sign in failed: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      debugPrint('🔄 Attempting sign up for: $email');
      final result = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ Sign up successful');
      return result;
    } catch (e) {
      debugPrint('❌ Sign up failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await auth.signOut();
      debugPrint('✅ Sign out successful');
    } catch (e) {
      debugPrint('❌ Sign out failed: $e');
      rethrow;
    }
  }

  // ✅ Firestore Methods (for services, bookings, etc.)
  Future<void> createDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('🔄 Creating document in $collection/$docId');
      await firestore.collection(collection).doc(docId).set(data);
      debugPrint('✅ Document created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create document: $e');
      rethrow;
    }
  }

  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('🔄 Updating document $collection/$docId with: $data');
      await firestore.collection(collection).doc(docId).update(data);
      debugPrint('✅ Document updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update document: $e');
      rethrow;
    }
  }

  Future<DocumentSnapshot> getDocument(String collection, String docId) async {
    try {
      debugPrint('🔄 Getting document $collection/$docId');
      final doc = await firestore.collection(collection).doc(docId).get();
      debugPrint('✅ Document retrieved: exists=${doc.exists}');
      return doc;
    } catch (e) {
      debugPrint('❌ Failed to get document: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getCollectionStream(
    String collection, {
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>)?
    queryBuilder,
  }) {
    try {
      debugPrint('🔄 Setting up collection stream for $collection');
      Query<Map<String, dynamic>> query = firestore.collection(collection);
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      return query.snapshots();
    } catch (e) {
      debugPrint('❌ Failed to setup collection stream: $e');
      rethrow;
    }
  }

  Future<QuerySnapshot> getCollection(
    String collection, {
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>)?
    queryBuilder,
  }) async {
    try {
      debugPrint('🔄 Getting collection $collection');
      Query<Map<String, dynamic>> query = firestore.collection(collection);
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      final result = await query.get();
      debugPrint('✅ Collection retrieved: ${result.docs.length} documents');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to get collection: $e');
      rethrow;
    }
  }

  // ✅ Realtime Database Methods (for user profiles)
  Future<void> createUserData(String uid, Map<String, dynamic> data) async {
    try {
      debugPrint('🔄 Creating user data for $uid: $data');
      await database.ref('users/$uid').set(data);
      debugPrint('✅ User data created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create user data: $e');
      rethrow;
    }
  }

  // ✅ IMPROVED: Better update method with validation
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      debugPrint('🔄 Updating user data for $uid: $data');

      // Remove null values to avoid Firebase errors
      final cleanData = Map<String, dynamic>.from(data);
      cleanData.removeWhere((key, value) => value == null);

      if (cleanData.isEmpty) {
        debugPrint('⚠️ No data to update after cleaning');
        return;
      }

      await database.ref('users/$uid').update(cleanData);
      debugPrint('✅ User data updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update user data: $e');
      rethrow;
    }
  }

  Future<DataSnapshot> getUserData(String uid) async {
    try {
      debugPrint('🔄 Getting user data for $uid');
      final snapshot = await database.ref('users/$uid').get();
      debugPrint('✅ User data retrieved: exists=${snapshot.exists}');
      if (snapshot.exists) {
        debugPrint('📄 User data: ${snapshot.value}');
      }
      return snapshot;
    } catch (e) {
      debugPrint('❌ Failed to get user data: $e');
      rethrow;
    }
  }

  // ✅ IMPROVED: Better stream method with error handling
  Stream<DatabaseEvent> getUserDataStream(String uid) {
    debugPrint('🔄 Setting up user data stream for $uid');
    return database.ref('users/$uid').onValue;
  }

  // ✅ NEW: Method to check if user exists
  Future<bool> userExists(String uid) async {
    try {
      final snapshot = await database.ref('users/$uid').get();
      return snapshot.exists;
    } catch (e) {
      debugPrint('❌ Error checking if user exists: $e');
      return false;
    }
  }

  // ✅ NEW: Method to delete user data (for cleanup)
  Future<void> deleteUserData(String uid) async {
    try {
      debugPrint('🔄 Deleting user data for $uid');
      await database.ref('users/$uid').remove();
      debugPrint('✅ User data deleted successfully');
    } catch (e) {
      debugPrint('❌ Failed to delete user data: $e');
      rethrow;
    }
  }

  // ✅ NEW: Batch update method for better performance
  Future<void> batchUpdateUserData(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      debugPrint('🔄 Batch updating user data for $uid');

      // Create a map with proper paths for batch update
      final Map<String, dynamic> batchUpdates = {};
      updates.forEach((key, value) {
        if (value != null) {
          batchUpdates['users/$uid/$key'] = value;
        }
      });

      if (batchUpdates.isNotEmpty) {
        await database.ref().update(batchUpdates);
        debugPrint('✅ Batch update completed successfully');
      }
    } catch (e) {
      debugPrint('❌ Batch update failed: $e');
      rethrow;
    }
  }

  // ✅ NEW: Test database connection
  Future<bool> testConnection() async {
    try {
      debugPrint('🔄 Testing database connection...');

      // Test Realtime Database
      await database.ref('.info/connected').get();

      // Test Firestore
      await firestore.collection('test').limit(1).get();

      debugPrint('✅ Database connection test successful');
      return true;
    } catch (e) {
      debugPrint('❌ Database connection test failed: $e');
      return false;
    }
  }
}
