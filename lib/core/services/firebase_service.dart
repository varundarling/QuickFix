import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();
  
  FirebaseService._();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseStorage get storage => FirebaseStorage.instance;

  Future<void> initalize() async {
    await Firebase.initializeApp(
      // options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  //Auth Methods
  Future<UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try{
      return await auth.signInWithEmailAndPassword(
        email : email,
        password : password,
      );
    } catch(e){
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmailPassword(
    String email,
    String password,
  ) async {
    try{
      return await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }catch(e){
      rethrow;
    }
  }

  Future<void> signOut() async{
    await auth.signOut();
  }

  //FireStore Methods
  Future<void> createDocument(
    String collection,
    String docId,
    Map<String,dynamic> data,
  ) async {
    await firestore.collection(collection).doc(docId).set(data);
  }

  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String,dynamic> data,
  ) async {
    await firestore.collection(collection).doc(docId).update(data);
  }

  Future<DocumentSnapshot> getDocument(
    String collection,
    String docId,
  ) async {
    return await firestore.collection(collection).doc(docId).get();
  }

  Stream<QuerySnapshot> getCollectionStream(
    String collection,{
      Query Function(Query)? queryBuilder,
    }
  ){
    Query query = firestore.collection(collection);
    if(queryBuilder != null){
      query = queryBuilder(query);
    }
    return query.snapshots();
  }

  Future<QuerySnapshot> getCollection(
    String collection,{
      Query Function(Query)? queryBuilder,
    }
  ) async {
    Query query = firestore.collection(collection);
    if(queryBuilder != null){
      query = queryBuilder(query);
    }
    return await query.get();
  }

}