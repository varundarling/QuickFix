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
  bool _isSigningIn = false;
  bool _isSigningUp = false;
  bool _isUpdatingProfile = false;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isSigningIn => _isSigningIn;
  bool get isSigningUp => _isSigningUp;
  bool get isUpdatingProfile => _isUpdatingProfile;

  void _setSignInLoading(bool loading) {
    _isSigningIn = loading;
    notifyListeners();
  }

  void _setSignUpLoading(bool loading) {
    _isSigningUp = loading;
    notifyListeners();
  }

  void _setUpdateProfileLoading(bool loading) {
    _isUpdatingProfile = loading;
    notifyListeners();
  }

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
      final doc = await _firebaseService.getUserData(
        _user!.uid,
      ); // ✅ Use Realtime DB
      if (doc.exists) {
        _userModel = UserModel.fromRealtimeDatabase(
          doc.value as Map<dynamic, dynamic>,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user model: $e');
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _setSignInLoading(true);
      _clearError();

      await _firebaseService.signInWithEmailPassword(email, password);
      return true;
    } catch (e) {
      _setError(_getErrorMessage(e));
      return false;
    } finally {
      _setSignInLoading(false);
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
      _setSignUpLoading(true);
      _clearError();

      final userCredential = await _firebaseService.signUpWithEmailPassword(
        email,
        password,
      );

      if (userCredential?.user != null) {
        //create new user
        final userModel = UserModel(
          id: userCredential!.user!.uid,
          name: name,
          email: email,
          phone: phone,
          userType: userType,
          createdAt: DateTime.now(),
        );

        await _firebaseService.createUserData(
          // ✅ Use Realtime DB for user data
          userCredential.user!.uid,
          userModel.toRealtimeDatabase(),
        );

        return true;
      }
      return false;
    } catch (e) {
      _setError(_getErrorMessage(e));
      return false;
    } finally {
      _setSignUpLoading(false);
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
      _setUpdateProfileLoading(true);

      // Create update data (only non-null values)
      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;
      if (photoUrl != null) updateData['photoUrl'] = photoUrl;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;
      if (address != null) updateData['address'] = address;
      updateData['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

      await _firebaseService.updateUserData(
        // ✅ Use Realtime DB
        _user!.uid,
        updateData,
      );

      debugPrint('✅ Profile updated successfully');

      // Immediately reload fresh data from Firestore
      await _loadUserModel();

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Profile update failed: $e');
      debugPrint('Stack: $stackTrace');
      _setError(_getErrorMessage(e));
      return false;
    } finally {
      debugPrint('🏁 Resetting loading state');
      _setUpdateProfileLoading(false);
    }
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
        case 'email-already-in-use':
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
