// ignore_for_file: prefer_final_fields, use_build_context_synchronously

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quickfix/core/services/encryption_service.dart';
import 'package:quickfix/core/services/firebase_service.dart';
import 'package:quickfix/core/services/notification_service.dart';
import 'package:quickfix/data/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GoogleAuthFlow { login, signup }

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService.instance;

  // ✅ FIXED: GoogleSignIn is now a singleton - no constructor parameters
  static const String kEncryptedKey = 'encrypted_profile';
  static const String kPublicKey = 'public_info';

  StreamSubscription<DatabaseEvent>? _userStreamSubscription;
  String? _pendingUserType;

  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSigningIn = false;
  bool _isSigningUp = false;
  bool _isUpdatingProfile = false;
  bool _isGoogleSigningIn = false;
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
  // Future<void> _ensureGoogleInitialized() async {
  //   if (_isGoogleInitialized) return;

  //   try {
  //     // ✅ CRITICAL: Replace with your actual Web Client ID
  //     await _googleSignIn.initialize(
  //       clientId:
  //           '638985318949-42ehidfh5rsdoapvmnd4rsvt6v86bjlo.apps.googleusercontent.com',
  //       serverClientId:
  //           '638985318949-42ehidfh5rsdoapvmnd4rsvt6v86bjlo.apps.googleusercontent.com',
  //     );
  //     _isGoogleInitialized = true;
  //     // ✅ CRITICAL: Request necessary permissions
  //   } catch (e) {
  //     // Log but don’t block UI
  //     throw e;
  //   }
  // }

  // ✅ FIXED: Complete Google Sign-In method for v7.1.1

  // Future<bool> signInWithGoogle({required bool isSignUp}) async {
  //   try {
  //     _setGoogleSignInLoading(true);
  //     _clearError();

  //     // 🔄 Starting Google Sign-In...

  //     await _ensureGoogleInitialized();

  //     GoogleSignInAccount? googleUser;

  //     if (_googleSignIn.supportsAuthenticate()) {
  //       googleUser = await _googleSignIn.authenticate();
  //     } else {
  //       throw Exception(
  //         'Google Sign-In authentication not supported on this platform',
  //       );
  //     }

  //     if (googleUser == null) {
  //       // User cancelled the sign-in
  //       return false;
  //     }

  //     // ✅ CRITICAL: Successfully obtained Google user

  //     // ✅ CRITICAL: Check if user exists in YOUR database
  //     final userExists = await _checkUserExistsInDatabase(googleUser.email!);

  //     // ✅ VALIDATION: Sign Up flow - user should NOT exist
  //     if (isSignUp && userExists) {
  //       // User already exists - cannot sign up again
  //       _setError('Account already exists. Please login instead.');
  //       await _googleSignIn.signOut();
  //       return false;
  //     }

  //     // ✅ VALIDATION: Login flow - user MUST exist
  //     if (!isSignUp && !userExists) {
  //       // User does not exist - cannot log in
  //       _setError('Account not found. Please Sign Up.');
  //       await _googleSignIn.signOut();
  //       return false;
  //     }

  //     // Proceed with Firebase authentication
  //     final GoogleSignInAuthentication googleAuth =
  //         await googleUser.authentication;

  //     if (googleAuth.idToken == null) {
  //       // Failed to get ID token
  //       return false;
  //     }

  //     // ✅ CRITICAL: Authenticate with Firebase using Google credentials
  //     final credential = GoogleAuthProvider.credential(
  //       idToken: googleAuth.idToken,
  //     );

  //     final UserCredential userCredential = await _firebaseService.auth
  //         .signInWithCredential(credential);

  //     if (userCredential.user != null) {
  //       _user = userCredential.user;

  //       // ✅ Handle based on flow type
  //       if (isSignUp) {
  //         // New user setup
  //         await _handleFirstTimeGoogleUser(userCredential.user!, googleUser);
  //         // Mark onboarding as seen
  //       } else {
  //         // Existing user setup
  //         await _handleExistingGoogleUser(userCredential.user!);
  //         // Load user profile
  //       }

  //       await _loadUserModel();
  //       await _setupNotifications();
  //       return true;
  //     }

  //     return false;
  //   } catch (e) {
  //     // Log error
  //     _setError(
  //       'Google ${isSignUp ? "Sign-Up" : "Login"} failed: ${e.toString()}',
  //     );
  //     return false;
  //   } finally {
  //     _setGoogleSignInLoading(false);
  //   }
  // }

  // ✅ Helper method: Check if user exists in your database
  // Future<bool> _checkUserExistsInDatabase(String email) async {
  //   try {
  //     // 🔍 Checking if user exists in database...

  //     // Method 1: Check in Firebase Realtime Database by email
  //     final query = await FirebaseDatabase.instance
  //         .ref('users')
  //         .orderByChild('email')
  //         .equalTo(email)
  //         .once();

  //     final exists = query.snapshot.exists;
  //     // Log result
  //     return exists;
  //   } catch (e) {
  //     // Log error
  //     // In case of error, assume user doesn't exist to be safe
  //     return false;
  //   }
  // }

  // ✅ Alternative method using Firebase's built-in approach
  Future<bool> signInWithGoogleAlternative() async {
    try {
      _setGoogleSignInLoading(true);
      _clearError();

      // 🔄 Starting Alternative Google Sign-In...

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
        // SignIn successful
        return true;
      }

      return false;
    } catch (e) {
      // SignIn failed
      _setError('Google Sign-In failed: ${e.toString()}');
      return false;
    } finally {
      _setGoogleSignInLoading(false);
    }
  }

  Future<void> _handleFirstTimeFirebaseGoogleUser(User user) async {
    final selectedUserType = _pendingUserType ?? 'customer';
    // 1) Initialize encryption
    final generatedPassword = _generatePasswordFromGoogleData(user);
    await EncryptionService.initializeUserEncryption(
      generatedPassword,
      user.uid,
    );

    // 2) Encrypt sensitive profile and save to RTDB
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
        'userType': selectedUserType,
        'isActive': true,
        'joinDate': ServerValue.timestamp,
        'provider': 'google',
        'hasCompletedProfile': false,
        'photoUrl': user.photoURL ?? '',
      },
      'access_requests': {},
    });

    // 3) (Optional) Minimal Firestore user doc for immediate presence
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'userType': selectedUserType,
      'photoUrl': user.photoURL ?? '',
      'isActive': true,
      'provider': 'google',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 4) Mark onboarding as seen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    // Persist chosen role immediately to avoid fallback mis-routing
    try {
      await _saveUserType(selectedUserType);
    } catch (_) {}
    _pendingUserType = null;
  }

  // Future<void> _handleFirstTimeGoogleUser(
  //   User user,
  //   GoogleSignInAccount googleUser,
  // ) async {
  //   try {
  //     // 🔄 Setting up first-time Google user

  //     final generatedPassword = _generatePasswordFromGoogleData(user);
  //     await EncryptionService.initializeUserEncryption(
  //       generatedPassword,
  //       user.uid,
  //     );

  //     final sensitiveData = {
  //       'name': user.displayName ?? googleUser.displayName ?? '',
  //       'email': user.email ?? '',
  //       'phone': '',
  //       'address': '',
  //     };

  //     final encryptedData = await EncryptionService.encryptUserData(
  //       sensitiveData,
  //       user.uid,
  //     );

  //     await FirebaseDatabase.instance.ref('users/${user.uid}').set({
  //       'encrypted_profile': encryptedData,
  //       'public_info': {
  //         'userType': 'customer',
  //         'isActive': true,
  //         'joinDate': ServerValue.timestamp,
  //         'provider': 'google',
  //         'hasCompletedProfile': false,
  //       },
  //       'access_requests': {},
  //     });

  //     await _saveUserType('customer');
  //     //✅ First-time Google user setup completed
  //   } catch (e) {
  //     // ❌ Error setting up first-time Google user
  //     throw e;
  //   }
  // }

  Future<void> _handleExistingGoogleUser(User user) async {
    try {
      // 🔄 Handling existing Google user

      final hasEncryption = EncryptionService.hasEncryptionSetup(
        user.uid,
      );

      if (!hasEncryption) {
        final generatedPassword = _generatePasswordFromGoogleData(user);
        await EncryptionService.initializeUserEncryption(
          generatedPassword,
          user.uid,
        );
        //✅ Restored encryption for existing Google user;
      } else {
        await EncryptionService.getMasterKey(user.uid);
        //✅ Restored encryption session for existing Google user
      }
    } catch (e) {
      //❌ Error handling existing Google user
      rethrow;
    }
  }

  String _generatePasswordFromGoogleData(User user) {
    final email = (user.email ?? '').trim().toLowerCase();
    return '${email}_${user.uid}_QuickFixAndroid2025';
  }

  Future<void> signOut() async {
    try {
      if (_user != null) {
        EncryptionService.clearSession(_user!.uid);
      }

      await _firebaseService.signOut();
      _user = null;
      _userModel = null;
      _clearError();

      debugPrint('✅ [AUTH] Signed out successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [AUTH] Sign out error: $e');
      _setError('Failed to sign out');
    }
  }

  String? getCurrentUserId() {
    final userId = _user?.uid;
    //🔍 Getting current user ID: $userId
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
    //✅ Saved user type: $userType
  }

  Future<String?> _getSavedUserType() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'user_type_${_user!.uid}';
    final userType = prefs.getString(key);
    //📱 Loaded saved user type: $userType
    return userType;
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
        //✅ Provider subscribed to provider notifications
      } else {
        await NotificationService.instance.subscribeTo('customers');
        await NotificationService.instance.unsubscribeFrom('providers');
        //✅ Customer subscribed to customer notifications
      }

      //✅ Notifications setup completed for $userType
    } catch (e) {
      //❌ Error setting up notifications
    }
  }

  AuthProvider() {
    debugPrint('🔄 [AUTH] AuthProvider initializing...');

    _firebaseService.auth.authStateChanges().listen((User? user) async {
      debugPrint('🔄 [AUTH] Auth state changed: ${user?.uid}');

      // Cleanup previous state
      await _stopUserProfileListener();
      _userModel = null;
      _user = user;

      if (user != null) {
        debugPrint('✅ [AUTH] User authenticated: ${user.email}');
        await _initializeUserSession(user);
      } else {
        _isInitialized = true;
        debugPrint('❌ [AUTH] User logged out');
      }
      notifyListeners();
    });
  }

  Future<void> _initializeUserSession(User user) async {
    try {
      debugPrint('🔄 [AUTH] Initializing session for: ${user.uid}');

      // STEP 1: Restore encryption session
      await _restoreEncryptionSession(user);

      // STEP 2: Load user data
      await _loadUserDataWithRetry();

      // STEP 3: Start real-time listener
      await _startUserProfileListener();

      _isInitialized = true;
      debugPrint('✅ [AUTH] Session initialized successfully');
    } catch (e) {
      debugPrint('❌ [AUTH] Session initialization error: $e');
      _isInitialized = true;
      _setError('Failed to load profile. Please try again.');
    }
  }

  Future<void> _loadUserDataWithRetry({int maxRetries = 3}) async {
    debugPrint('🔄 [AUTH] Loading user data with retries...');

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('🔄 [AUTH] Load attempt $attempt of $maxRetries');

        final doc = await _firebaseService.getUserData(_user!.uid);
        if (doc.exists) {
          final data = doc.value as Map<dynamic, dynamic>;
          await _handleUserDataUpdate(Map<String, dynamic>.from(data));

          if (_userModel != null) {
            debugPrint('✅ [AUTH] User model loaded: ${_userModel!.name}');
            return;
          }
        } else {
          debugPrint('⚠️ [AUTH] No user data found in database');
          break;
        }
      } catch (e) {
        debugPrint('❌ [AUTH] Load attempt $attempt failed: $e');

        if (attempt < maxRetries) {
          final delay = Duration(milliseconds: 300 * attempt);
          debugPrint('⏳ [AUTH] Waiting ${delay.inMilliseconds}ms before retry');
          await Future.delayed(delay);
        }
      }
    }

    debugPrint('❌ [AUTH] All load attempts failed');
  }

  Future<void> _restoreEncryptionSession(User user) async {
    try {
      debugPrint('🔐 [AUTH] Restoring encryption session...');

      // Check if session already exists
      if (EncryptionService.isSessionReady(user.uid)) {
        debugPrint('✅ [AUTH] Session already ready');
        return;
      }

      // Try to restore from secure storage first
      final restored = await EncryptionService.restoreEncryptionSession(
        user.uid,
      );
      if (restored) {
        debugPrint('✅ [AUTH] Session restored from storage');
        return;
      }

      // For Google users, regenerate deterministic password
      final isGoogleUser = user.providerData.any(
        (info) => info.providerId == 'google.com',
      );

      if (isGoogleUser) {
        debugPrint('🔄 [AUTH] Regenerating Google user encryption...');
        final generatedPassword = _generatePasswordFromGoogleData(user);
        await EncryptionService.initializeUserEncryption(
          generatedPassword,
          user.uid,
        );
        debugPrint('✅ [AUTH] Google user encryption regenerated');
      } else {
        // For email users, they need to re-login if session is lost
        debugPrint('⚠️ [AUTH] Email user - session lost, need re-login');
        throw Exception('Session expired. Please login again.');
      }
    } catch (e) {
      debugPrint('❌ [AUTH] Encryption session restoration failed: $e');
      // Don't throw - let app continue with public info only
    }
  }

  Future<void> _loadUserModelWithRetry({int maxRetries = 3}) async {
    // Attempt to load user model with retries

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Log each attempt

        final doc = await _firebaseService.getUserData(_user!.uid);
        if (doc.exists) {
          final data = doc.value as Map<dynamic, dynamic>;
          await _handleUserDataUpdate(Map<String, dynamic>.from(data));

          if (_userModel != null) {
            // Successfully loaded user model
            return;
          }
        } else {
          // No user data found
          break; // Don't retry if no data exists
        }
      } catch (e) {
        // Log the error but continue to retry

        if (attempt < maxRetries) {
          // Wait before retrying, with exponential backoff
          final delay = Duration(milliseconds: 500 * attempt);
          // Log the delay
          await Future.delayed(delay);
        }
      }
    }

    // If we reach here, all attempts failed
  }

  Future<bool> ensureUserAuthenticated() async {
    // If already authenticated and profile loaded, return true

    // Wait for initialization to complete
    if (!_isInitialized) {
      // Wait max 10 seconds
      int waitCount = 0;
      while (!_isInitialized && waitCount < 20) {
        // Max 10 seconds
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;
      }
    }

    if (_user == null) {
      // Not logged in
      return false;
    }

    if (_userModel == null) {
      // Try loading user model if not already loaded
      await _loadUserModelWithRetry();
    }

    final isAuth = _user != null && _userModel != null;
    // Log final status
    return isAuth;
  }

  Future<String> getUserType() async {
    // Ensure user is authenticated first

    // Wait for initialization if not complete
    if (!_isInitialized && _user != null) {
      // Wait max 10 seconds
      int waitCount = 0;
      while (!_isInitialized && waitCount < 20) {
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;
      }
    }

    // Try to get from loaded user model first
    if (_userModel?.userType != null) {
      // Save to cache
      await _saveUserType(_userModel!.userType);
      return _userModel!.userType;
    }

    // Try to load fresh data from database
    if (_user != null) {
      try {
        await _loadUserModelWithRetry(maxRetries: 2);
        if (_userModel?.userType != null) {
          // Save to cache
          await _saveUserType(_userModel!.userType);
          return _userModel!.userType;
        }
        // Direct lookup from RTDB to avoid defaulting incorrectly
        try {
          final snap = await FirebaseDatabase.instance
              .ref('users/${_user!.uid}/public_info/userType')
              .get();
          if (snap.exists && snap.value is String) {
            final directType = (snap.value as String).toLowerCase();
            await _saveUserType(directType);
            return directType;
          }
        } catch (_) {}
        // Secondary lookup from Firestore if RTDB path missing
        try {
          final fs = await FirebaseFirestore.instance
              .collection('users')
              .doc(_user!.uid)
              .get();
          final fsType = fs.data()?['userType'];
          if (fs.exists && fsType is String && fsType.isNotEmpty) {
            final t = fsType.toLowerCase();
            await _saveUserType(t);
            return t;
          }
        } catch (_) {}
      } catch (e) {
        // Log but don’t block UI
      }
    }

    // Fallback to cached user type
    final savedUserType = await _getSavedUserType();
    if (savedUserType != null) {
      // Use cached value
      return savedUserType;
    }

    // Default fallback
    return 'customer';
  }

  Future<void> _startUserProfileListener() async {
    if (_user == null) return;

    await _stopUserProfileListener();
    debugPrint('🔄 [AUTH] Starting real-time listener');

    _userStreamSubscription = FirebaseDatabase.instance
        .ref('users')
        .child(_user!.uid)
        .onValue
        .listen(
          (DatabaseEvent event) async {
            debugPrint('📡 [AUTH] Real-time update received');
            final DataSnapshot snapshot = event.snapshot;

            if (snapshot.exists && snapshot.value != null) {
              final data = Map<String, dynamic>.from(snapshot.value as Map);
              await _handleUserDataUpdate(data);
            }
          },
          onError: (error) {
            debugPrint('❌ [AUTH] Real-time listener error: $error');
          },
        );
  }

  Future<void> _handleUserDataUpdate(Map<String, dynamic> data) async {
    try {
      debugPrint('🔄 [AUTH] Processing user data update...');

      // Normalize keys (handle both old and new formats)
      final normalized = _normalizeProfileSnapshot(data);

      if (normalized.containsKey(kEncryptedKey)) {
        final encryptedProfile = normalized[kEncryptedKey] as String;
        final publicInfo = normalized[kPublicKey] as Map<dynamic, dynamic>?;

        // Try to decrypt the profile
        try {
          // Ensure session is ready before decryption
          if (!EncryptionService.isSessionReady(_user!.uid)) {
            debugPrint('⚠️ [AUTH] Session not ready, attempting restore...');
            await _restoreEncryptionSession(_user!);
          }

          final decryptedData = await EncryptionService.decryptUserData(
            encryptedProfile,
            _user!.uid,
          );

          if (decryptedData != null) {
            // Merge encrypted data with public info
            final combinedData = Map<String, dynamic>.from(decryptedData);
            if (publicInfo != null) {
              combinedData.addAll(Map<String, dynamic>.from(publicInfo));
            }

            _userModel = UserModel.fromRealtimeDatabase(combinedData);
            debugPrint('✅ [AUTH] Full encrypted profile loaded');
          } else {
            throw Exception('Decryption returned null');
          }
        } catch (e) {
          debugPrint('❌ [AUTH] Decryption failed: $e');

          // Fall back to public info only
          if (publicInfo != null) {
            _userModel = UserModel.fromRealtimeDatabase(
              Map<String, dynamic>.from(publicInfo),
            );
            debugPrint('⚠️ [AUTH] Using public info only (decryption failed)');
          } else {
            debugPrint('❌ [AUTH] No fallback data available');
          }
        }
      } else {
        // No encryption, use data as-is
        _userModel = UserModel.fromRealtimeDatabase(data);
        debugPrint('✅ [AUTH] Using unencrypted profile data');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ [AUTH] Error handling user data update: $e');
      _setError('Failed to load user profile.');
    }
  }

  Map<String, dynamic> _normalizeProfileSnapshot(Map raw) {
    final map = Map<String, dynamic>.from(raw);

    // Handle legacy key names
    if (!map.containsKey(kEncryptedKey) &&
        map.containsKey('encryptedprofile')) {
      map[kEncryptedKey] = map['encryptedprofile'];
    }
    if (!map.containsKey(kPublicKey) && map.containsKey('publicinfo')) {
      map[kPublicKey] = map['publicinfo'];
    }

    return map;
  }

  Future<void> _stopUserProfileListener() async {
    await _userStreamSubscription?.cancel();
    _userStreamSubscription = null;
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
      // Log but don’t block UI
    }
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential result = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (result.user != null) {
        await requestNotificationPermissionAfterLogin();
        // Restore encryption session
        notifyListeners();
        return true;
      }
    } catch (e) {
      // Log but don’t block UI
    }
    return false;
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _setSignInLoading(true);
      _clearError();

      await _firebaseService.signInWithEmailPassword(email, password);

      if (_user != null) {
        await EncryptionService.getMasterKey(_user!.uid, password);
      }

      // Shared after-auth work for identical UX
      await postAuthBootstrap();
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
      if (userCredential?.user == null) return false;

      _user = userCredential!.user;

      // Encryption + RTDB encrypted profile
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

      // Minimal Firestore presence for parity with Google and downstream queries
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'name': name,
        'email': email,
        'userType': userType,
        'isActive': true,
        'provider': 'email',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _saveUserType(userType);

      // Shared after-auth work for identical UX
      await postAuthBootstrap();
      return true;
    } catch (e) {
      _setError(_getErrorMessage(e));
      return false;
    } finally {
      _setSignUpLoading(false);
    }
  }

  Future<bool> _userRecordExistsByEmail(String? email) async {
    if (email == null || email.isEmpty) return false;
    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return q.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> loginWithGoogleStrict({String userType = 'customer'}) async {
    _pendingUserType = userType; // Store for consistency
    return await continueWithGoogleStrict(flow: GoogleAuthFlow.login);
  }

  Future<bool> signUpWithGoogleStrict({String userType = 'customer'}) async {
    _pendingUserType = userType; // Store the intended user type
    return await continueWithGoogleStrict(flow: GoogleAuthFlow.signup);
  }

  Future<void> postAuthBootstrap() async {
    try {
      // Load user profile from RTDB (with retry) → populates _userModel
      await _loadUserModelWithRetry();

      // Persist role locally for correct dashboard routing after app restarts
      if (_userModel?.userType != null) {
        await _saveUserType(_userModel!.userType);
      }

      // Set up FCM token + topic subscriptions without blocking the first frame
      unawaited(_setupNotifications());

      // Permanently skip onboarding after first successful auth
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasSeenOnboarding', true);

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // Log but don’t block UI
      _isInitialized = true; // don’t block UI on errors
    }
  }

  Future<bool> continueWithGoogleStrict({required GoogleAuthFlow flow}) async {
    _setGoogleSignInLoading(true);
    _clearError();
    try {
      final googleProvider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');

      // Signs in or creates the Firebase Auth user for Google provider
      final UserCredential cred = await FirebaseAuth.instance
          .signInWithProvider(googleProvider);

      final user = cred.user;
      if (user == null) {
        _setError('Google Sign-In failed.');
        return false;
      }

      final email = user.email;
      final existsInDb = await _userRecordExistsByEmail(email);

      // Guard 1: Login path requires an existing DB record
      if (flow == GoogleAuthFlow.login && !existsInDb) {
        _setError('Account not found. Please sign up first.');
        // Cleanup the just-created auth account to avoid orphans
        try {
          await user.delete();
        } catch (_) {}
        await FirebaseAuth.instance.signOut();
        return false;
      }

      // Guard 2: Signup path must not already exist in DB
      if (flow == GoogleAuthFlow.signup && existsInDb) {
        _setError('Account already exists. Please login first.');
        // If Firebase just created the auth user for this attempt, delete it
        if (cred.additionalUserInfo?.isNewUser ?? false) {
          try {
            await user.delete();
          } catch (_) {}
        }
        await FirebaseAuth.instance.signOut();
        return false;
      }

      // Proceed normally based on whether this Google auth is new or returning
      if (cred.additionalUserInfo?.isNewUser ?? false) {
        // First-time Google auth → run "new user" bootstrap only for signup flow
        // If flow was login but DB had a record (edge case), fall back to existing handler
        if (flow == GoogleAuthFlow.signup) {
          await _handleFirstTimeFirebaseGoogleUser(user);
        } else {
          await _handleExistingGoogleUser(user);
        }
      } else {
        await _handleExistingGoogleUser(user);
      }

      await postAuthBootstrap();
      return true;
    } catch (e) {
      _setError('Google Sign-In failed: ${e.toString()}');
      return false;
    } finally {
      _setGoogleSignInLoading(false);
    }
  }

  // Future<bool> _userProfileExists(String uid) async {
  //   try {
  //     final rtdb = await FirebaseDatabase.instance.ref('users/$uid').get();
  //     if (rtdb.exists) return true;

  //     final fs = await FirebaseFirestore.instance
  //         .collection('users')
  //         .doc(uid)
  //         .get();
  //     return fs.exists;
  //   } catch (_) {
  //     return false;
  //   }
  // }

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
    // profileData can include any additional fields to update

    if (_user == null) {
      // User must be authenticated
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

      // Save sensitive data encrypted in RTDB
      // Public data to update

      if (sensitiveUpdateData.isNotEmpty) {
        final snapshot = await FirebaseDatabase.instance
            .ref('users/${_user!.uid}/encrypted_profile')
            .get();

        Map<String, dynamic> existingData = {};
        if (snapshot.exists) {
          try {
            existingData = (await EncryptionService.decryptUserData(
              snapshot.value as String,
              _user!.uid,
            ))!;
          } catch (e) {
            // If decryption fails, log but continue with empty existing data
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

      // Refresh local user model
      return true;
    } catch (e) {
      // Log and set error state
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
    if (_user == null) {
      debugPrint('⚠️ [AUTH] Cannot reload: No user logged in');
      return;
    }

    try {
      debugPrint('🔄 [AUTH] Manual reload requested');

      final snapshot = await FirebaseDatabase.instance
          .ref('users')
          .child(_user!.uid)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        await _handleUserDataUpdate(data);
        debugPrint('✅ [AUTH] Manual reload completed');
      } else {
        debugPrint('⚠️ [AUTH] No data found during manual reload');
      }
    } catch (e) {
      debugPrint('❌ [AUTH] Manual reload failed: $e');
    }
  }

  Future<void> requestNotificationPermissionAfterLogin() async {
    try {
      await Future.delayed(Duration(seconds: 1));
      PermissionStatus status = await Permission.notification.status;

      if (status.isGranted) {
        // Permission already granted
        await _initializeFCMToken();
        return;
      }

      if (status.isDenied) {
        // Request permission
        PermissionStatus newStatus = await Permission.notification.request();

        if (newStatus.isGranted) {
          // Permission granted
          await _initializeFCMToken();
        } else {
          // User denied permission
        }
      } else if (status.isPermanentlyDenied) {
        // Cannot request permission directly
      }
    } catch (e) {
      // Log but don’t throw
    }
  }

  Future<void> _initializeFCMToken() async {
    try {
      String? fcmToken = await NotificationService.instance.getToken();

      if (fcmToken != null) {
        await _saveFCMTokenToFirestore(fcmToken);
      }
    } catch (e) {
      // Log but don’t throw
    }
  }

  Future<void> _saveFCMTokenToFirestore(String fcmToken) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Save token to both 'users' and 'providers' collections if applicable

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
        // FCM Token saved successfully
      }
    } catch (e) {
      // Log but don’t throw
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
      return;
    }

    try {
      final rtdbSnapshot = await FirebaseDatabase.instance
          .ref('users')
          .child(currentUser.uid)
          .get();

      // Check if Realtime DB record exists
      if (rtdbSnapshot.exists) {
        // Limit output size for readability
      }

      try {
        final firestoreDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        // Check if Firestore document exists
        if (firestoreDoc.exists) {
          // Limit output size for readability
        }
      } catch (e) {
        // Handle Firestore access errors
      }
    } catch (e) {
      // Handle any errors that occur during the fetch
    }
  }

  Future<void> updateUserToken(String userId) async {
    final token = await NotificationService.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> subscribeTo(String topic) async {
    await NotificationService.instance.subscribeTo(topic);
  }

  Future<void> unsubscribeFrom(String topic) async {
    await NotificationService.instance.unsubscribeFrom(topic);
  }

  Future<String?> getToken() async {
    try {
      return await NotificationService.instance.getToken();
    } catch (e) {
      return null;
    }
  }
}
