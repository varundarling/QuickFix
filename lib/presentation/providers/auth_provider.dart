import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quickfix/core/services/encryption_service.dart';
import 'package:quickfix/core/services/firebase_service.dart';
import 'package:quickfix/core/services/notification_service.dart';
import 'package:quickfix/data/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService.instance;

  // ✅ FIXED: GoogleSignIn is now a singleton - no constructor parameters
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  StreamSubscription<DatabaseEvent>? _userStreamSubscription;

  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSigningIn = false;
  bool _isSigningUp = false;
  bool _isUpdatingProfile = false;
  bool _isGoogleSigningIn = false;
  bool _isGoogleInitialized = false;
  bool _isInitialized = false;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isSigningIn => _isSigningIn;
  bool get isSigningUp => _isSigningUp;
  bool get isUpdatingProfile => _isUpdatingProfile;
  bool get isGoogleSigningIn => _isGoogleSigningIn;
  bool get isInitialized => _isInitialized;

  void _setSignInLoading(bool loading) {
    _isSigningIn = loading;
    notifyListeners();
  }

  void _setGoogleSignInLoading(bool loading) {
    _isGoogleSigningIn = loading;
    notifyListeners();
  }

  // ✅ FIXED: Correct initialization for v7.1.1
  Future<void> _ensureGoogleInitialized() async {
    if (_isGoogleInitialized) return;

    try {
      // ✅ CRITICAL: Replace with your actual Web Client ID
      await _googleSignIn.initialize(
        clientId:
            '638985318949-42ehidfh5rsdoapvmnd4rsvt6v86bjlo.apps.googleusercontent.com',
        serverClientId:
            '638985318949-42ehidfh5rsdoapvmnd4rsvt6v86bjlo.apps.googleusercontent.com',
      );
      _isGoogleInitialized = true;
      debugPrint('✅ Google Sign-In initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Google Sign-In: $e');
      throw e;
    }
  }

  // ✅ FIXED: Complete Google Sign-In method for v7.1.1

  Future<bool> signInWithGoogle({required bool isSignUp}) async {
    try {
      _setGoogleSignInLoading(true);
      _clearError();

      debugPrint('🔄 Starting Google ${isSignUp ? "Sign-Up" : "Login"}...');

      await _ensureGoogleInitialized();

      GoogleSignInAccount? googleUser;

      if (_googleSignIn.supportsAuthenticate()) {
        googleUser = await _googleSignIn.authenticate();
      } else {
        throw Exception(
          'Google Sign-In authentication not supported on this platform',
        );
      }

      if (googleUser == null) {
        debugPrint(
          '❌ Google ${isSignUp ? "Sign-Up" : "Login"} cancelled by user',
        );
        return false;
      }

      debugPrint('✅ Google user obtained: ${googleUser.email}');

      // ✅ CRITICAL: Check if user exists in YOUR database
      final userExists = await _checkUserExistsInDatabase(googleUser.email!);

      // ✅ VALIDATION: Sign Up flow - user should NOT exist
      if (isSignUp && userExists) {
        debugPrint('❌ User already exists: ${googleUser.email}');
        _setError('Account already exists. Please login instead.');
        await _googleSignIn.signOut();
        return false;
      }

      // ✅ VALIDATION: Login flow - user MUST exist
      if (!isSignUp && !userExists) {
        debugPrint('❌ User not found: ${googleUser.email}');
        _setError('Account not found. Please Sign Up.');
        await _googleSignIn.signOut();
        return false;
      }

      // Proceed with Firebase authentication
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        debugPrint('❌ Failed to get Google ID token');
        return false;
      }

      debugPrint('✅ Google tokens obtained successfully');

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseService.auth
          .signInWithCredential(credential);

      if (userCredential.user != null) {
        _user = userCredential.user;

        // ✅ Handle based on flow type
        if (isSignUp) {
          // New user setup
          await _handleFirstTimeGoogleUser(userCredential.user!, googleUser);
          debugPrint('✅ Google Sign-Up successful for new user');
        } else {
          // Existing user setup
          await _handleExistingGoogleUser(userCredential.user!);
          debugPrint('✅ Google Login successful for existing user');
        }

        await _loadUserModel();
        await _setupNotifications();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Google ${isSignUp ? "Sign-Up" : "Login"} error: $e');
      _setError(
        'Google ${isSignUp ? "Sign-Up" : "Login"} failed: ${e.toString()}',
      );
      return false;
    } finally {
      _setGoogleSignInLoading(false);
    }
  }

  // ✅ Helper method: Check if user exists in your database
  Future<bool> _checkUserExistsInDatabase(String email) async {
    try {
      debugPrint('🔍 Checking if user exists in database: $email');

      // Method 1: Check in Firebase Realtime Database by email
      final query = await FirebaseDatabase.instance
          .ref('users')
          .orderByChild('email')
          .equalTo(email)
          .once();

      final exists = query.snapshot.exists;
      debugPrint('📊 User exists in database: $exists');
      return exists;
    } catch (e) {
      debugPrint('❌ Error checking user existence: $e');
      // In case of error, assume user doesn't exist to be safe
      return false;
    }
  }

  // ✅ Alternative method using Firebase's built-in approach
  Future<bool> signInWithGoogleAlternative() async {
    try {
      _setGoogleSignInLoading(true);
      _clearError();

      debugPrint('🔄 Starting alternative Google Sign-In...');

      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithProvider(googleProvider);

      if (userCredential.user != null) {
        _user = userCredential.user;

        if (userCredential.additionalUserInfo?.isNewUser ?? false) {
          await _handleFirstTimeFirebaseGoogleUser(userCredential.user!);
        } else {
          await _handleExistingGoogleUser(userCredential.user!);
        }

        await _loadUserModel();
        await _setupNotifications();
        debugPrint('✅ Alternative Google Sign-In successful');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Alternative Google Sign-In error: $e');
      _setError('Google Sign-In failed: ${e.toString()}');
      return false;
    } finally {
      _setGoogleSignInLoading(false);
    }
  }

  Future<void> _handleFirstTimeFirebaseGoogleUser(User user) async {
    try {
      debugPrint('🆕 Setting up first-time Firebase Google user');

      final generatedPassword = _generatePasswordFromGoogleData(user);
      await EncryptionService.initializeUserEncryption(
        generatedPassword,
        user.uid,
      );

      final sensitiveData = {
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'phone': '',
        'address': '',
      };

      final encryptedData = await EncryptionService.encryptUserData(
        sensitiveData,
        user.uid,
      );

      await FirebaseDatabase.instance.ref('users/${user.uid}').set({
        'encrypted_profile': encryptedData,
        'public_info': {
          'userType': 'customer',
          'isActive': true,
          'joinDate': ServerValue.timestamp,
          'provider': 'google',
          'hasCompletedProfile': false,
          'photoUrl': user.photoURL ?? '',
        },
        'access_requests': {},
      });

      await _saveUserType('customer');
      debugPrint('✅ First-time Firebase Google user setup completed');
    } catch (e) {
      debugPrint('❌ Error setting up first-time Firebase Google user: $e');
      throw e;
    }
  }

  Future<void> _handleFirstTimeGoogleUser(
    User user,
    GoogleSignInAccount googleUser,
  ) async {
    try {
      debugPrint('🆕 Setting up first-time Google user');

      final generatedPassword = _generatePasswordFromGoogleData(user);
      await EncryptionService.initializeUserEncryption(
        generatedPassword,
        user.uid,
      );

      final sensitiveData = {
        'name': user.displayName ?? googleUser.displayName ?? '',
        'email': user.email ?? '',
        'phone': '',
        'address': '',
      };

      final encryptedData = await EncryptionService.encryptUserData(
        sensitiveData,
        user.uid,
      );

      await FirebaseDatabase.instance.ref('users/${user.uid}').set({
        'encrypted_profile': encryptedData,
        'public_info': {
          'userType': 'customer',
          'isActive': true,
          'joinDate': ServerValue.timestamp,
          'provider': 'google',
          'hasCompletedProfile': false,
        },
        'access_requests': {},
      });

      await _saveUserType('customer');
      debugPrint('✅ First-time Google user setup completed');
    } catch (e) {
      debugPrint('❌ Error setting up first-time Google user: $e');
      throw e;
    }
  }

  Future<void> _handleExistingGoogleUser(User user) async {
    try {
      debugPrint('🔄 Handling existing Google user');

      final hasEncryption = await EncryptionService.hasEncryptionSetup(
        user.uid,
      );

      if (!hasEncryption) {
        final generatedPassword = _generatePasswordFromGoogleData(user);
        await EncryptionService.initializeUserEncryption(
          generatedPassword,
          user.uid,
        );
        debugPrint('✅ Restored encryption for existing Google user');
      } else {
        await EncryptionService.getMasterKey(user.uid);
        debugPrint('✅ Restored encryption session for existing Google user');
      }
    } catch (e) {
      debugPrint('❌ Error handling existing Google user: $e');
      throw e;
    }
  }

  String _generatePasswordFromGoogleData(User user) {
    final data = '${user.email}_${user.uid}_quickfix_google_2025';
    final bytes = utf8.encode(data);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ✅ FIXED: Updated signOut for v7.1.1
  Future<void> signOut() async {
    try {
      if (_user != null) {
        await _clearUserType();
        EncryptionService.clearSession(_user!.uid);
      }

      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
      await _firebaseService.signOut();

      _user = null;
      _userModel = null;
      _clearError();

      debugPrint('👋 User signed out and user type cleared');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      _setError(_getErrorMessage(e));
    }
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

  Future<void> _saveUserType(String userType) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'user_type_${_user!.uid}';
    await prefs.setString(key, userType);
    debugPrint('✅ Saved user type: $userType');
  }

  Future<String?> _getSavedUserType() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'user_type_${_user!.uid}';
    final userType = prefs.getString(key);
    debugPrint('📱 Loaded saved user type: $userType');
    return userType;
  }

  Future<void> _clearUserType() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'user_type_${_user!.uid}';
    await prefs.remove(key);
    debugPrint('🗑️ Cleared saved user type');
  }

  Future<void> _setupNotifications() async {
    if (_user == null) return;

    try {
      String? fcmToken = await NotificationService.instance.getToken();
      if (fcmToken != null) {
        await _saveFCMTokenToFirestore(fcmToken);
      }

      final userType = _userModel?.userType.toLowerCase() ?? 'customer';

      if (userType == 'provider') {
        await NotificationService.instance.subscribeTo('providers');
        await NotificationService.instance.unsubscribeFrom('customers');
        debugPrint('✅ Provider subscribed to provider notifications');
      } else {
        await NotificationService.instance.subscribeTo('customers');
        await NotificationService.instance.unsubscribeFrom('providers');
        debugPrint('✅ Customer subscribed to customer notifications');
      }

      debugPrint('✅ Notifications setup completed for $userType');
    } catch (e) {
      debugPrint('❌ Error setting up notifications: $e');
    }
  }

  AuthProvider() {
    _firebaseService.auth.authStateChanges().listen((User? user) async {
      debugPrint('🔄 Auth state changed: ${user?.uid}');
      _user = user;

      if (user != null) {
        debugPrint('✅ User authenticated: ${user.email}');

        // ✅ CRITICAL: Ensure proper initialization sequence
        await _initializeUserSession(user);
      } else {
        _stopUserProfileListener();
        _userModel = null;
        _isInitialized = true; // ✅ Mark as initialized even when logged out
        debugPrint('❌ User logged out');
      }
      notifyListeners();
    });
  }

  Future<void> _initializeUserSession(User user) async {
    try {
      debugPrint('🔄 Initializing user session for: ${user.uid}');

      // ✅ STEP 1: Restore encryption session first
      await _restoreEncryptionSession(user);

      // ✅ STEP 2: Load user profile with retry logic
      await _loadUserModelWithRetry();

      // ✅ STEP 3: Start real-time listener only after profile is loaded
      await _startUserProfileListener();

      // ✅ STEP 4: Setup notifications
      await _setupNotifications();

      _isInitialized = true;
      debugPrint('✅ User session initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing user session: $e');
      _isInitialized = true; // Mark as initialized to prevent infinite loading
    }
  }

  Future<Map<String, dynamic>?> _safeDecryptUserData(
    String encryptedData,
    String userUID,
    BuildContext? context,
  ) async {
    try {
      // First, ensure encryption session is ready
      if (!EncryptionService.isSessionReady(userUID)) {
        debugPrint('🔐 Session not ready, attempting to restore...');
        final restored = await EncryptionService.restoreEncryptionSession(
          userUID,
        );

        if (!restored) {
          debugPrint('❌ Failed to restore encryption session');
          await _handleEncryptionFailure(context);
          return null;
        }
      }

      return await EncryptionService.decryptUserData(encryptedData, userUID);
    } catch (e) {
      debugPrint('❌ Decryption failed: $e');

      if (e.toString().contains('No decryption key')) {
        await _handleEncryptionFailure(context);
        return null;
      }
      rethrow;
    }
  }

  Future<void> _handleEncryptionFailure(BuildContext? context) async {
    debugPrint('🔑 Handling encryption failure...');

    try {
      // For Google users, try to regenerate encryption
      if (_user?.providerData.any((info) => info.providerId == 'google.com') ==
          true) {
        debugPrint('🔄 Attempting to regenerate Google user encryption...');
        final generatedPassword = _generatePasswordFromGoogleData(_user!);
        await EncryptionService.initializeUserEncryption(
          generatedPassword,
          _user!.uid,
        );
        debugPrint('✅ Google user encryption regenerated');
        return;
      }
    } catch (e) {
      debugPrint('❌ Failed to regenerate encryption: $e');
    }

    // Show user-friendly error and prompt re-authentication
    if (context != null) {
      _showReAuthenticationDialog(context);
    } else {
      // Set error state if no context available
      _setError('Session expired. Please login again to continue.');
    }
  }

  // Show re-authentication dialog
  void _showReAuthenticationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '🔐 Session Expired',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Your secure session has expired. Please login again to continue using the app safely.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await signOut();
              // Navigate to login screen
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text(
              'Login Again',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreEncryptionSession(User user) async {
    try {
      debugPrint('🔐 Restoring encryption session for: ${user.uid}');

      // Check if encryption is already set up
      final hasEncryption = await EncryptionService.hasEncryptionSetup(
        user.uid,
      );

      if (hasEncryption) {
        // Try to restore from device storage
        final masterKey = await EncryptionService.getMasterKey(user.uid);
        if (masterKey != null) {
          debugPrint('✅ Encryption session restored from device storage');
          return;
        }
      }

      // ✅ For Google users, regenerate the password-based encryption
      if (user.providerData.any((info) => info.providerId == 'google.com')) {
        debugPrint('🔄 Regenerating encryption for Google user');
        final generatedPassword = _generatePasswordFromGoogleData(user);
        await EncryptionService.initializeUserEncryption(
          generatedPassword,
          user.uid,
        );
        debugPrint('✅ Google user encryption restored');
      } else {
        // ✅ For email users, we need them to re-enter password if session is lost
        debugPrint(
          '⚠️ Email user encryption session lost - may need re-authentication',
        );
      }
    } catch (e) {
      debugPrint('❌ Error restoring encryption: $e');
      // Don't throw - let the app continue and handle missing profile gracefully
    }
  }

  Future<void> _loadUserModelWithRetry({int maxRetries = 3}) async {
    debugPrint('🔄 Loading user profile with retry logic...');

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('🔄 Profile load attempt $attempt/$maxRetries');

        final doc = await _firebaseService.getUserData(_user!.uid);
        if (doc.exists) {
          final data = doc.value as Map<dynamic, dynamic>;
          await _handleUserDataUpdate(Map<String, dynamic>.from(data));

          if (_userModel != null) {
            debugPrint(
              '✅ User profile loaded successfully on attempt $attempt',
            );
            return;
          }
        } else {
          debugPrint('⚠️ No user data found in database');
          break; // Don't retry if no data exists
        }
      } catch (e) {
        debugPrint('❌ Profile load attempt $attempt failed: $e');

        if (attempt < maxRetries) {
          // Wait before retrying, with exponential backoff
          final delay = Duration(milliseconds: 500 * attempt);
          debugPrint('⏳ Waiting ${delay.inMilliseconds}ms before retry...');
          await Future.delayed(delay);
        }
      }
    }

    debugPrint('❌ All profile load attempts failed');
  }

  Future<bool> ensureUserAuthenticated() async {
    debugPrint('🔍 Checking user authentication status...');

    // Wait for initialization to complete
    if (!_isInitialized) {
      debugPrint('⏳ Waiting for initialization to complete...');
      int waitCount = 0;
      while (!_isInitialized && waitCount < 20) {
        // Max 10 seconds
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;
      }
    }

    if (_user == null) {
      debugPrint('❌ User not authenticated');
      return false;
    }

    if (_userModel == null) {
      debugPrint(
        '⚠️ User authenticated but profile not loaded, attempting to load...',
      );
      await _loadUserModelWithRetry();
    }

    final isAuth = _user != null && _userModel != null;
    debugPrint(
      '✅ User authentication status: $isAuth (Profile: ${_userModel?.name})',
    );
    return isAuth;
  }

  Future<String> getUserType() async {
    debugPrint('🔍 Getting user type for user: ${_user?.uid}');

    // Wait for initialization if not complete
    if (!_isInitialized && _user != null) {
      debugPrint('⏳ Waiting for user initialization...');
      int waitCount = 0;
      while (!_isInitialized && waitCount < 20) {
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;
      }
    }

    // Try to get from loaded user model first
    if (_userModel?.userType != null) {
      debugPrint('🔥 Got user type from loaded model: ${_userModel!.userType}');
      await _saveUserType(_userModel!.userType);
      return _userModel!.userType;
    }

    // Try to load fresh data from database
    if (_user != null) {
      try {
        await _loadUserModelWithRetry(maxRetries: 2);
        if (_userModel?.userType != null) {
          debugPrint('🔥 Got fresh user type: ${_userModel!.userType}');
          await _saveUserType(_userModel!.userType);
          return _userModel!.userType;
        }
      } catch (e) {
        debugPrint('❌ Failed to load from database: $e');
      }
    }

    // Fallback to cached user type
    final savedUserType = await _getSavedUserType();
    if (savedUserType != null) {
      debugPrint('💾 Using cached user type: $savedUserType');
      return savedUserType;
    }

    debugPrint('⚠️ Defaulting to customer');
    return 'customer';
  }

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

                _handleUserDataUpdate(data);
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

  Future<void> _handleUserDataUpdate(Map<String, dynamic> data) async {
  try {
    if (data.containsKey('encrypted_profile')) {
      final encryptedProfile = data['encrypted_profile'] as String;
      final publicInfo = data['public_info'] as Map<dynamic, dynamic>?;

      // ✅ Use safe decryption method
      final decryptedData = await _safeDecryptUserData(
        encryptedProfile,
        _user!.uid,
        null, // No context available here
      );

      if (decryptedData != null) {
        final combinedData = Map<String, dynamic>.from(decryptedData);
        if (publicInfo != null) {
          combinedData.addAll(Map<String, dynamic>.from(publicInfo));
        }

        _userModel = UserModel.fromRealtimeDatabase(combinedData);
        debugPrint('✅ Encrypted user model updated: Name="${_userModel?.name}"');
      } else {
        // Fall back to public info only if decryption fails
        if (publicInfo != null) {
          _userModel = UserModel.fromRealtimeDatabase(
            Map<String, dynamic>.from(publicInfo),
          );
          debugPrint('⚠️ Using public info only due to decryption failure');
        }
      }
    } else {
      _userModel = UserModel.fromRealtimeDatabase(data);
      debugPrint('✅ User model updated: Name="${_userModel?.name}"');
    }

    notifyListeners();
  } catch (e) {
    debugPrint('❌ Error handling user data update: $e');
    _setError('Failed to load user profile. Please try again.');
  }
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
        final data = doc.value as Map<dynamic, dynamic>;
        await _handleUserDataUpdate(Map<String, dynamic>.from(data));
        await _setupNotifications();
      }
    } catch (e) {
      debugPrint('❌ Error loading user model: $e');
    }
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential result = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (result.user != null) {
        await requestNotificationPermissionAfterLogin();
        debugPrint('✅ User signed in successfully');
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('❌ Sign in error: $e');
    }
    return false;
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _setSignInLoading(true);
      _clearError();

      await _firebaseService.signInWithEmailPassword(email, password);

      if (_user != null) {
        await EncryptionService.getMasterKey(_user!.uid, password: password);
      }

      await _loadUserModel();
      if (_userModel?.userType != null) {
        await _saveUserType(_userModel!.userType);
        debugPrint(
          '✅ Sign-in successful for user type: ${_userModel!.userType}',
        );
        await _setupNotifications();
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
        _user = userCredential!.user;

        await EncryptionService.initializeUserEncryption(password, _user!.uid);

        final sensitiveData = {'name': name, 'email': email, 'phone': phone};

        final encryptedData = await EncryptionService.encryptUserData(
          sensitiveData,
          _user!.uid,
        );

        await FirebaseDatabase.instance.ref('users/${_user!.uid}').set({
          'encrypted_profile': encryptedData,
          'public_info': {
            'userType': userType,
            'isActive': true,
            'joinDate': ServerValue.timestamp,
            'provider': 'email',
            'hasCompletedProfile': false,
          },
          'access_requests': {},
        });

        await _saveUserType(userType);
        debugPrint('✅ Sign-up successful for user type: $userType');
        await _setupNotifications();

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

    if (_user == null) {
      debugPrint('❌ User not authenticated');
      _setError('User not authenticated');
      return false;
    }

    try {
      _setUpdateProfileLoading(true);

      final Map<String, dynamic> sensitiveUpdateData = {};
      final Map<String, dynamic> publicUpdateData = {};

      if (name != null) sensitiveUpdateData['name'] = name;
      if (phone != null) sensitiveUpdateData['phone'] = phone;
      if (address != null) sensitiveUpdateData['address'] = address;
      if (businessName != null) {
        sensitiveUpdateData['businessName'] = businessName;
      }
      if (description != null) sensitiveUpdateData['description'] = description;
      if (experience != null) sensitiveUpdateData['experience'] = experience;

      if (photoUrl != null) publicUpdateData['photoUrl'] = photoUrl;
      if (latitude != null) publicUpdateData['latitude'] = latitude;
      if (longitude != null) publicUpdateData['longitude'] = longitude;

      if (profileData != null) {
        profileData.forEach((key, value) {
          if ([
            'name',
            'phone',
            'address',
            'businessName',
            'description',
            'experience',
          ].contains(key)) {
            sensitiveUpdateData[key] = value;
          } else {
            publicUpdateData[key] = value;
          }
        });
      }

      debugPrint('📝 Sensitive update data: $sensitiveUpdateData');
      debugPrint('📝 Public update data: $publicUpdateData');

      if (sensitiveUpdateData.isNotEmpty) {
        final snapshot = await FirebaseDatabase.instance
            .ref('users/${_user!.uid}/encrypted_profile')
            .get();

        Map<String, dynamic> existingData = {};
        if (snapshot.exists) {
          try {
            existingData = await EncryptionService.decryptUserData(
              snapshot.value as String,
              _user!.uid,
            );
          } catch (e) {
            debugPrint('❌ Failed to decrypt existing data: $e');
          }
        }

        existingData.addAll(sensitiveUpdateData);

        final encryptedData = await EncryptionService.encryptUserData(
          existingData,
          _user!.uid,
        );

        await FirebaseDatabase.instance
            .ref('users/${_user!.uid}/encrypted_profile')
            .set(encryptedData);
      }

      if (publicUpdateData.isNotEmpty) {
        publicUpdateData['updatedAt'] = ServerValue.timestamp;

        await FirebaseDatabase.instance
            .ref('users/${_user!.uid}/public_info')
            .update(publicUpdateData);
      }

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
    _stopUserProfileListener();
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
    return 'An unexpected error has occurred. Please try again.';
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
        await _handleUserDataUpdate(data);
        debugPrint('✅ Manual reload successful');
      } else {
        debugPrint('⚠️ No data found during manual reload');
      }
    } catch (e) {
      debugPrint('❌ Manual reload failed: $e');
    }
  }

  Future<void> requestNotificationPermissionAfterLogin() async {
    try {
      await Future.delayed(Duration(seconds: 1));
      PermissionStatus status = await Permission.notification.status;

      if (status.isGranted) {
        debugPrint('✅ Notification permission already granted');
        await _initializeFCMToken();
        return;
      }

      if (status.isDenied) {
        debugPrint('🔔 Requesting notification permission...');
        PermissionStatus newStatus = await Permission.notification.request();

        if (newStatus.isGranted) {
          debugPrint('✅ Notification permission granted');
          await _initializeFCMToken();
        } else {
          debugPrint('❌ Notification permission denied');
        }
      } else if (status.isPermanentlyDenied) {
        debugPrint('❌ Notification permission permanently denied');
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
    }
  }

  Future<void> _initializeFCMToken() async {
    try {
      String? fcmToken = await NotificationService.instance.getToken();

      if (fcmToken != null) {
        await _saveFCMTokenToFirestore(fcmToken);
        debugPrint('✅ FCM token initialized and saved');
      } else {
        debugPrint('❌ Failed to get FCM token');
      }
    } catch (e) {
      debugPrint('❌ Error initializing FCM token: $e');
    }
  }

  Future<void> _saveFCMTokenToFirestore(String fcmToken) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        debugPrint(
          '💾 [AUTH] Saving FCM token: ${fcmToken.substring(0, 20)}...',
        );

        final batch = FirebaseFirestore.instance.batch();

        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid);
        batch.set(userRef, {
          'fcmToken': fcmToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'isActive': true,
        }, SetOptions(merge: true));

        final userType = _userModel?.userType.toLowerCase() ?? '';
        if (userType == 'provider') {
          final providerRef = FirebaseFirestore.instance
              .collection('providers')
              .doc(currentUser.uid);
          batch.set(providerRef, {
            'fcmToken': fcmToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'isActive': true,
          }, SetOptions(merge: true));
        }

        await batch.commit();
        debugPrint('✅ [AUTH] FCM token saved to Firestore successfully');
      }
    } catch (e) {
      debugPrint('❌ [AUTH] Error saving FCM token: $e');
    }
  }

  bool get isCustomerProfileComplete {
    if (userModel == null) return false;

    return userModel!.name.isNotEmpty &&
        userModel!.phone.isNotEmpty &&
        userModel!.address != null &&
        userModel!.address!.isNotEmpty;
  }

  bool get isProviderProfileComplete {
    if (userModel == null) return false;

    return userModel!.name.isNotEmpty &&
        userModel!.phone.isNotEmpty &&
        userModel!.address != null &&
        userModel!.address!.isNotEmpty &&
        userModel!.businessName != null &&
        userModel!.businessName!.isNotEmpty &&
        userModel!.experience != null &&
        userModel!.experience!.isNotEmpty;
  }

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

      final rtdbSnapshot = await FirebaseDatabase.instance
          .ref('users')
          .child(currentUser.uid)
          .get();

      debugPrint('Realtime DB exists: ${rtdbSnapshot.exists}');
      if (rtdbSnapshot.exists) {
        debugPrint('Realtime DB data: ${rtdbSnapshot.value}');
      }

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

  Future<void> updateUserToken(String userId) async {
    try {
      final token = await NotificationService.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('✅ Updated FCM token for user: $userId');
      }
    } catch (e) {
      debugPrint('❌ Error updating user token: $e');
    }
  }

  Future<void> subscribeTo(String topic) async {
    try {
      await NotificationService.instance.subscribeTo(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic $topic: $e');
    }
  }

  Future<void> unsubscribeFrom(String topic) async {
    try {
      await NotificationService.instance.unsubscribeFrom(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic $topic: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      return await NotificationService.instance.getToken();
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }
}
