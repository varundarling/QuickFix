import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/services/firebase_service.dart';
import 'package:quickfix/data/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService.instance;

  StreamSubscription<DatabaseEvent>? _userStreamSubscription;

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

  Future<bool> ensureUserAuthenticated() async {
    debugPrint('🔍 Checking user authentication status...');

    if (_user == null) {
      // Wait a bit for auth state to restore
      await Future.delayed(const Duration(milliseconds: 500));

      // Force reload current user
      await FirebaseAuth.instance.currentUser?.reload();
      _user = FirebaseAuth.instance.currentUser;

      debugPrint('🔄 Current user after reload: ${_user?.uid}');
    }

    if (_user != null && _userModel == null) {
      debugPrint('🔄 Loading user model...');
      await _loadUserModel();
    }

    final isAuth = _user != null;
    debugPrint('✅ User authentication status: $isAuth');
    return isAuth;
  }

  String? getCurrentUserId() {
    final userId = _user?.uid;
    debugPrint('🔍 Getting current user ID: $userId');
    return userId;
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
        await _startUserProfileListener();
      } else {
        _stopUserProfileListener(); // ✅ Stop listener
        _userModel = null;
      }
      notifyListeners();
    });
  }

  // ✅ CRITICAL: Start real-time listener for automatic updates
  Future<void> _startUserProfileListener() async {
    if (_user == null) return;

    await _userStreamSubscription?.cancel();
    debugPrint('🔄 Starting Realtime DB listener for: ${_user!.uid}');

    _userStreamSubscription = FirebaseDatabase.instance
        .ref('users')
        .child(_user!.uid)
        .onValue
        .listen(
          (DatabaseEvent event) {
            debugPrint('🔄 Realtime update received from Firebase');
            final DataSnapshot snapshot = event.snapshot;

            if (snapshot.exists && snapshot.value != null) {
              try {
                final data = Map<String, dynamic>.from(snapshot.value as Map);
                debugPrint('📡 Raw Firebase data: $data');

                _userModel = UserModel.fromRealtimeDatabase(data);
                debugPrint(
                  '✅ User model updated: Name="${_userModel?.name}", Address="${_userModel?.address}"',
                );
                notifyListeners(); // ✅ CRITICAL: This updates the UI
              } catch (e) {
                debugPrint('❌ Error parsing user data: $e');
              }
            } else {
              debugPrint('⚠️ No user data found in Realtime DB');
            }
          },
          onError: (error) {
            debugPrint('❌ Realtime listener error: $error');
          },
        );
  }

  void _stopUserProfileListener() {
    _userStreamSubscription?.cancel();
    _userStreamSubscription = null;
    debugPrint('🛑 Stopped Realtime DB listener');
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

  // ✅ UPDATED: Added experience parameter
  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
    double? latitude,
    double? longitude,
    String? address,
    String? businessName,
    String? description,
    String? experience,
    Map<String, dynamic>? profileData,
  }) async {
    debugPrint('🔄 Starting profile update...');
    debugPrint(
      '📝 Update data: name="$name", phone="$phone", address="$address"',
    );

    if (_user == null) {
      debugPrint('❌ User not authenticated');
      _setError('User not authenticated');
      return false;
    }

    try {
      _setUpdateProfileLoading(true);

      final Map<String, dynamic> updateData = {};

      // Add profileData if provided
      if (profileData != null) {
        updateData.addAll(profileData);
      }

      // Add individual parameters (only if not null)
      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;
      if (photoUrl != null) updateData['photoUrl'] = photoUrl;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;
      if (address != null) updateData['address'] = address;
      if (businessName != null) updateData['businessName'] = businessName;
      if (description != null) updateData['description'] = description;
      if (experience != null) updateData['experience'] = experience;

      // Add server timestamp
      updateData['updatedAt'] = ServerValue.timestamp;

      debugPrint('📝 Update data prepared: $updateData');

      // ✅ Use Realtime Database update
      await FirebaseDatabase.instance
          .ref('users')
          .child(_user!.uid)
          .update(updateData);

      debugPrint('✅ Profile update completed successfully');

      return true;
    } catch (e) {
      debugPrint('❌ Profile update failed: $e');
      _setError('Failed to update profile: ${e.toString()}');
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

  @override
  void dispose() {
    _stopUserProfileListener(); // ✅ Clean up
    super.dispose();
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
    if (_user == null) return;

    try {
      debugPrint('🔄 Manually reloading user data...');

      final snapshot = await FirebaseDatabase.instance
          .ref('users')
          .child(_user!.uid)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        _userModel = UserModel.fromRealtimeDatabase(data);
        debugPrint(
          '✅ Manual reload successful: Address="${_userModel?.address}"',
        );
        notifyListeners();
      } else {
        debugPrint('⚠️ No data found during manual reload');
      }
    } catch (e) {
      debugPrint('❌ Manual reload failed: $e');
    }
  }

  /// Check if customer profile is complete
  bool get isCustomerProfileComplete {
    if (userModel == null) return false;

    return userModel!.name.isNotEmpty &&
        userModel!.phone.isNotEmpty &&
        userModel!.address != null &&
        userModel!.address!.isNotEmpty;
  }

  /// Check if provider profile is complete
  bool get isProviderProfileComplete {
    if (userModel == null) return false;

    return userModel!.name.isNotEmpty &&
        userModel!.phone.isNotEmpty &&
        userModel!.address != null &&
        userModel!.address!.isNotEmpty &&
        userModel!.businessName != null &&
        userModel!.businessName!.isNotEmpty &&
        userModel!.experience != null &&
        userModel!
            .experience!
            .isNotEmpty; // ✅ UPDATED: Check for non-empty string
  }

  /// Get missing profile fields for customer
  List<String> get missingCustomerFields {
    if (userModel == null) return ['All profile information'];

    List<String> missing = [];
    if (userModel!.name.isEmpty) missing.add('Full Name');
    if (userModel!.phone.isEmpty) missing.add('Phone Number');
    if (userModel!.address == null || userModel!.address!.isEmpty) {
      missing.add('Address');
    }
    return missing;
  }

  /// Get missing profile fields for provider
  List<String> get missingProviderFields {
    if (userModel == null) return ['All profile information'];

    List<String> missing = [];
    if (userModel!.name.isEmpty) missing.add('Full Name');
    if (userModel!.phone.isEmpty) missing.add('Phone Number');
    if (userModel!.address == null || userModel!.address!.isEmpty) {
      missing.add('Address');
    }
    if (userModel!.businessName == null || userModel!.businessName!.isEmpty) {
      missing.add('Business Name');
    }
    // ✅ UPDATED: Check for experience as string, not number
    if (userModel!.experience == null || userModel!.experience!.isEmpty) {
      missing.add('Experience');
    }
    return missing;
  }

  Future<void> debugUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('❌ No authenticated user');
      return;
    }

    try {
      debugPrint('=== DATABASE DEBUG ===');
      debugPrint('User ID: ${currentUser.uid}');
      debugPrint('Email: ${currentUser.email}');

      // Check Realtime Database
      final rtdbSnapshot = await FirebaseDatabase.instance
          .ref('users')
          .child(currentUser.uid)
          .get();

      debugPrint('Realtime DB exists: ${rtdbSnapshot.exists}');
      if (rtdbSnapshot.exists) {
        debugPrint('Realtime DB data: ${rtdbSnapshot.value}');
      }

      // Check if accidentally using Firestore
      try {
        final firestoreDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        debugPrint('Firestore doc exists: ${firestoreDoc.exists}');
        if (firestoreDoc.exists) {
          debugPrint('Firestore data: ${firestoreDoc.data()}');
        }
      } catch (e) {
        debugPrint('Firestore check failed (normal if not using it): $e');
      }

      debugPrint('====================');
    } catch (e) {
      debugPrint('❌ Debug failed: $e');
    }
  }
}
