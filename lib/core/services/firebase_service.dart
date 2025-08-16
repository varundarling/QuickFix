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

  Future<void> initalize() async {
    await Firebase.initializeApp();
  }

  // Auth Methods
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      return await auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmailPassword(String email, String password) async {
    try {
      return await auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  // ✅ Firestore Methods (for bookings, services, etc.)
  Future<void> createDocument(String collection, String docId, Map<String, dynamic> data) async {
    await firestore.collection(collection).doc(docId).set(data);
  }

  Future<void> updateDocument(String collection, String docId, Map<String, dynamic> data) async {
    await firestore.collection(collection).doc(docId).update(data);
  }

  Future<DocumentSnapshot> getDocument(String collection, String docId) async {
    return await firestore.collection(collection).doc(docId).get();
  }

  Stream<QuerySnapshot> getCollectionStream(
    String collection, {
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>)? queryBuilder,
  }) {
    Query<Map<String, dynamic>> query = firestore.collection(collection);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return query.snapshots();
  }

  Future<QuerySnapshot> getCollection(
    String collection, {
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>)? queryBuilder,
  }) async {
    Query<Map<String, dynamic>> query = firestore.collection(collection);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return await query.get();
  }

  // ✅ Realtime Database Methods (for user data only)
  Future<void> createUserData(String uid, Map<String, dynamic> data) async {
    await database.ref('users/$uid').set(data);
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await database.ref('users/$uid').update(data);
  }

  Future<DataSnapshot> getUserData(String uid) async {
    return await database.ref('users/$uid').get();
  }

  Stream<DatabaseEvent> getUserDataStream(String uid) {
    return database.ref('users/$uid').onValue;
  }
}
