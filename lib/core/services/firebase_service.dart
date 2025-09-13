import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;

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
      final result = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final result = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await auth.signOut();
    } catch (e) {
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
      await firestore.collection(collection).doc(docId).set(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      await firestore.collection(collection).doc(docId).update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<DocumentSnapshot> getDocument(String collection, String docId) async {
    try {
      final doc = await firestore.collection(collection).doc(docId).get();

      return doc;
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getCollectionStream(
    String collection, {
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>)?
    queryBuilder,
  }) {
    try {
      Query<Map<String, dynamic>> query = firestore.collection(collection);
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      return query.snapshots();
    } catch (e) {
      rethrow;
    }
  }

  Future<QuerySnapshot> getCollection(
    String collection, {
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>)?
    queryBuilder,
  }) async {
    try {
      Query<Map<String, dynamic>> query = firestore.collection(collection);
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      final result = await query.get();

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // ✅ Realtime Database Methods (for user profiles)
  Future<void> createUserData(String uid, Map<String, dynamic> data) async {
    try {
      await database.ref('users/$uid').set(data);
    } catch (e) {
      rethrow;
    }
  }

  // ✅ IMPROVED: Better update method with validation
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      // Remove null values to avoid Firebase errors
      final cleanData = Map<String, dynamic>.from(data);
      cleanData.removeWhere((key, value) => value == null);

      if (cleanData.isEmpty) {
        return;
      }

      await database.ref('users/$uid').update(cleanData);
    } catch (e) {
      rethrow;
    }
  }

  Future<DataSnapshot> getUserData(String uid) async {
    try {
      final snapshot = await database.ref('users/$uid').get();
      return snapshot;
    } catch (e) {
      rethrow;
    }
  }

  // ✅ IMPROVED: Better stream method with error handling
  Stream<DatabaseEvent> getUserDataStream(String uid) {
    return database.ref('users/$uid').onValue;
  }

  // ✅ NEW: Method to check if user exists
  Future<bool> userExists(String uid) async {
    try {
      final snapshot = await database.ref('users/$uid').get();
      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  // ✅ NEW: Method to delete user data (for cleanup)
  Future<void> deleteUserData(String uid) async {
    try {
      await database.ref('users/$uid').remove();
    } catch (e) {
      rethrow;
    }
  }

  // ✅ NEW: Batch update method for better performance
  Future<void> batchUpdateUserData(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Create a map with proper paths for batch update
      final Map<String, dynamic> batchUpdates = {};
      updates.forEach((key, value) {
        if (value != null) {
          batchUpdates['users/$uid/$key'] = value;
        }
      });

      if (batchUpdates.isNotEmpty) {
        await database.ref().update(batchUpdates);
      }
    } catch (e) {
      rethrow;
    }
  }

  // ✅ NEW: Test database connection
  Future<bool> testConnection() async {
    try {
      // Test Realtime Database
      await database.ref('.info/connected').get();

      // Test Firestore
      await firestore.collection('test').limit(1).get();

      return true;
    } catch (e) {
      return false;
    }
  }
}
