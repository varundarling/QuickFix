import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/services/firebase_service.dart';
import 'package:quickfix/data/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String? getCurrentUserId() {
    return _user?.uid;
  }

  Future<bool> ensureUserAuthenticated() async {
    if (_user == null) {
      // Wait a bit for auth state to restore
      await Future.delayed(const Duration(milliseconds: 500));

      // Force reload current user
      await FirebaseAuth.instance.currentUser?.reload();
      _user = FirebaseAuth.instance.currentUser;

      if (_user != null && _userModel == null) {
        await _loadUserModel();
      }
    }

    return _user != null;
  }

  void _setSignUpLoading(bool loading) {
    _isSigningUp = loading;
    notifyListeners();
  }

  void _setUpdateProfileLoading(bool loading) {
    _isUpdatingProfile = loading;
    notifyListeners();
  }

  // ✅ Add these methods after your getters
  Future<void> _saveUserType(String userType) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'user_type_${_user!.uid}'; // ✅ User-specific key
    await prefs.setString(key, userType);
    debugPrint('✅ Saved user type: $userType');
  }

  Future<String?> _getSavedUserType() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'user_type_${_user!.uid}'; // ✅ User-specific key
    final userType = prefs.getString(key);
    debugPrint('📱 Loaded saved user type: $userType');
    return userType;
  }

  Future<void> _clearUserType() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'user_type_${_user!.uid}'; // ✅ User-specific key
    await prefs.remove(key);
    debugPrint('🗑️ Cleared saved user type');
  }

  AuthProvider() {
    //Auth state changes
    _firebaseService.auth.authStateChanges().listen((User? user) async {
      debugPrint('🔄 Auth state changed: ${user?.uid}');
      _user = user;
      if (user != null) {
        debugPrint('✅ User authenticated: ${user.email}');
        await _loadUserModel();
        await _validateUserData();
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserModel() async {
    if (_user == null) return;

    try {
      final doc = await _firebaseService.getUserData(_user!.uid);
      if (doc.exists) {
        _userModel = UserModel.fromRealtimeDatabase(
          doc.value as Map<dynamic, dynamic>,
        );
        debugPrint('✅ User model updated: ${_userModel?.address}');
        notifyListeners(); // ✅ Make sure this is called
      }
    } catch (e) {
      debugPrint('❌ Error loading user model: $e');
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _setSignInLoading(true);
      _clearError();

      await _firebaseService.signInWithEmailPassword(email, password);
      await _loadUserModel();
      if (_userModel?.userType != null) {
        await _saveUserType(_userModel!.userType);
        debugPrint(
          '✅ Sign-in successful for user type: ${_userModel!.userType}',
        );
      }
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

        await _saveUserType(userType);
        debugPrint('✅ Sign-up successful for user type: $userType');

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
      // ✅ Clear user type for current user before signing out
      if (user != null) {
        await _clearUserType();
      }

      await _firebaseService.signOut();
      _user = null;
      _userModel = null;
      _clearError();

      debugPrint('👋 User signed out and user type cleared');
      notifyListeners();
    } catch (e) {
      _setError(_getErrorMessage(e));
    }
  }

  // ✅ Add this method to validate user data
  Future<bool> _validateUserData() async {
    if (_user == null || _userModel == null) return false;

    try {
      // Get fresh data from Firebase
      final doc = await _firebaseService.getUserData(_user!.uid);
      if (doc.exists) {
        final freshUserModel = UserModel.fromRealtimeDatabase(
          doc.value as Map<dynamic, dynamic>,
        );

        // Check if cached data matches Firebase data
        final isSameUserType = _userModel!.userType == freshUserModel.userType;
        if (!isSameUserType) {
          debugPrint(
            '⚠️ User type mismatch detected! Cached: ${_userModel!.userType}, Firebase: ${freshUserModel.userType}',
          );
          // Update with fresh data
          _userModel = freshUserModel;
          await _saveUserType(freshUserModel.userType);
          notifyListeners();
        }

        return true;
      }
    } catch (e) {
      debugPrint('❌ Error validating user data: $e');
    }

    return false;
  }

  Future<String> getUserType() async {
    debugPrint('🔍 Getting user type for user: ${_user?.uid}');

    // ✅ Always prioritize fresh database data
    if (_user != null) {
      try {
        await _loadUserModel();
        if (_userModel?.userType != null) {
          debugPrint('🔥 Got fresh user type: ${_userModel!.userType}');
          await _saveUserType(_userModel!.userType);
          return _userModel!.userType;
        }
      } catch (e) {
        debugPrint('❌ Failed to load from database: $e');
      }
    }

    // Fallback to cached data
    final savedUserType = await _getSavedUserType();
    if (savedUserType != null) {
      debugPrint('💾 Using cached user type: $savedUserType');
      return savedUserType;
    }

    debugPrint('⚠️ Defaulting to customer');
    return 'customer';
  }

  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    debugPrint('🔄 Starting profile update...');
    debugPrint('📍 New address: $address');
    debugPrint('📍 New coords: $latitude, $longitude');

    if (_user == null || _userModel == null) return false;

    try {
      _setUpdateProfileLoading(true);

      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;
      if (photoUrl != null) updateData['photoUrl'] = photoUrl;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;
      if (address != null) updateData['address'] = address;
      updateData['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

      await _firebaseService.updateUserData(_user!.uid, updateData);
      debugPrint('✅ Firebase update successful');

      // ✅ Reload user model
      await _loadUserModel();
      debugPrint('✅ User model reloaded');
      debugPrint('📍 New user address: ${_userModel?.address}');
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('❌ Profile update failed: $e');
      _setError(_getErrorMessage(e));
      return false;
    } finally {
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

  // Add this method that was missing
  Future<UserModel?> _loadUserFromDatabase(String uid) async {
    try {
      final doc = await _firebaseService.getUserData(uid);
      if (doc.exists) {
        return UserModel.fromRealtimeDatabase(
          doc.value as Map<dynamic, dynamic>,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error loading user from database: $e');
      return null;
    }
  }

  Future<void> reloadUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _userModel = null;
        notifyListeners();
        return;
      }

      // ✅ Load user data from database
      final userData = await _loadUserFromDatabase(currentUser.uid);

      if (userData != null) {
        _userModel = userData;
        // ✅ Update cached user type
        await _saveUserType(userData.userType);
        notifyListeners();
        debugPrint('✅ User data reloaded: ${userData.userType}');
      }
    } catch (e) {
      debugPrint('Error reloading user data: $e');
    }
  }
}
