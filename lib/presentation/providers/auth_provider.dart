import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/services/firebase_service.dart';
import 'package:quickfix/data/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService.instance;

  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    //Auth state changes
    _firebaseService.auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserModel();
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserModel() async {
    if (_user == null) return;

    try {
      final doc = await _firebaseService.getDocument('users', _user!.uid);
      if (doc.exists) {
        _userModel = UserModel.fromFireStore(doc);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user model: $e');
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      await _firebaseService.signInWithEmailPassword(email, password);
      return true;
    } catch (e) {
      _setError(_getErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    String userType = 'customer',
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // ignore: non_constant_identifier_names
      final UserCredential = await _firebaseService.signUpWithEmailPassword(
        email,
        password,
      );

      if (UserCredential?.user != null) {
        //create new user
        final userModel = UserModel(
          id: UserCredential!.user!.uid,
          name: name,
          email: email,
          phone: phone,
          userType: userType,
          createdAt: DateTime.now(),
        );

        await _firebaseService.createDocument(
          'users',
          UserCredential.user!.uid,
          userModel.toFireStore(),
        );

        return true;
      }
      return false;
    } catch (e) {
      _setError(_getErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseService.signOut();
      _user = null;
      _userModel = null;
      notifyListeners();
    } catch (e) {
      _setError(_getErrorMessage(e));
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    if (_user == null || _userModel == null) return false;

    try {
      _setLoading(true);

      final updatedUser = _userModel!.copyWith(
        name: name,
        phone: phone,
        photoUrl: photoUrl,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

      await _firebaseService.updateDocument(
        'users',
        _user!.uid,
        updatedUser.toFireStore(),
      );

      _userModel = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_getErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'eamil-already-in-user':
          return 'Email is already in use.';
        case 'weak-password':
          return 'Password is too weak.';
        case 'invalid-email':
          return 'Invalid Email address.';

        default:
          return 'Authentication failed. Please try again.';
      }
    }
    return 'An expected error has occurred. Please try again.';
  }
}
