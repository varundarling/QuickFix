// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart';
import 'encryption_service.dart';

class GoogleSignInService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  static bool _isInitialized = false;

  static Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    try {
      await _googleSignIn.initialize();
      _isInitialized = true;
      print('✅ Google Sign-In initialized');
    } catch (e) {
      print('❌ Error initializing Google Sign-In: $e');
      throw e;
    }
  }

  // ✅ Corrected implementation for v7.1.1
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      print('🔄 Starting Google Sign-In...');

      await _ensureInitialized();

      GoogleSignInAccount? googleUser;

      // ✅ Try authenticate() first
      if (_googleSignIn.supportsAuthenticate()) {
        try {
          googleUser = await _googleSignIn.authenticate();
          print('✅ Authentication successful via authenticate()');
        } catch (e) {
          print('❌ authenticate() failed: $e, trying alternative approach');
          googleUser = null;
        }
      }

      // ✅ Fallback: For v7.1.1, we need to handle this differently
      if (googleUser == null) {
        // Try to get account from authentication events
        print('🔄 Attempting to get user from authentication events...');

        // Create a completer to wait for authentication event
        final completer = Completer<GoogleSignInAccount?>();
        late StreamSubscription subscription;

        subscription = _googleSignIn.authenticationEvents.listen((event) {
          switch (event) {
            case GoogleSignInAuthenticationEventSignIn():
              completer.complete(event.user);
              subscription.cancel();
              break;
            case GoogleSignInAuthenticationEventSignOut():
              if (!completer.isCompleted) {
                completer.complete(null);
                subscription.cancel();
              }
              break;
          }
        });

        // Trigger authentication (this might work on some platforms)
        try {
          await _googleSignIn.authenticate();
        } catch (e) {
          print('❌ Authentication trigger failed: $e');
        }

        // Wait for result with timeout
        googleUser = await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            subscription.cancel();
            return null;
          },
        );
      }

      if (googleUser == null) {
        print('❌ Google Sign-In failed - no user obtained');
        return null;
      }

      print('✅ Google user obtained: ${googleUser.email}');

      // ✅ For v7.1.1, we need to get the ID token differently
      String? idToken;
      String? accessToken;

      try {
        // Try to get authorization for Firebase scopes
        final authorization = await googleUser.authorizationClient
            .authorizationForScopes(['openid', 'email', 'profile']);

        if (authorization != null) {
          accessToken = authorization.accessToken;
          // ✅ For v7.1.1, idToken might be in a different property or method
          // Try to access it through the authorization client
          try {
            // Check if there's an idToken property we missed
            idToken = (authorization as dynamic).idToken as String?;
          } catch (e) {
            print('❌ Could not get idToken from authorization: $e');
          }
        }
      } catch (e) {
        print('❌ Authorization failed: $e');
      }

      // ✅ Alternative approach: Use Firebase Auth with just the access token
      if (accessToken != null && idToken == null) {
        print('⚠️ Only access token available, attempting Firebase auth...');

        // For some cases, we might need to create a credential differently
        // This is a workaround for v7.1.1 limitations
        try {
          final credential = GoogleAuthProvider.credential(
            accessToken: accessToken,
            // Try without idToken first
          );

          final userCredential = await _auth.signInWithCredential(credential);

          if (userCredential.user != null) {
            await _handleUserSetup(
              userCredential.user!,
              googleUser,
              userCredential.additionalUserInfo?.isNewUser ?? false,
            );
            return userCredential;
          }
        } catch (e) {
          print('❌ Firebase auth with access token only failed: $e');
        }
      }

      // ✅ Standard approach if we have both tokens
      if (accessToken != null && idToken != null) {
        final credential = GoogleAuthProvider.credential(
          accessToken: accessToken,
          idToken: idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);

        if (userCredential.user != null) {
          await _handleUserSetup(
            userCredential.user!,
            googleUser,
            userCredential.additionalUserInfo?.isNewUser ?? false,
          );
          return userCredential;
        }
      }

      print('❌ Could not obtain necessary tokens for Firebase authentication');
      return null;
    } catch (e) {
      print('❌ Google Sign-In Error: $e');
      return null;
    }
  }

  // ✅ Unified user setup handler
  static Future<void> _handleUserSetup(
    User user,
    GoogleSignInAccount googleUser,
    bool isNewUser,
  ) async {
    if (isNewUser) {
      await _handleFirstTimeGoogleUser(user, googleUser);
    } else {
      await _handleExistingGoogleUser(user);
    }
  }

  static Future<void> _handleFirstTimeGoogleUser(
    User user,
    GoogleSignInAccount googleUser,
  ) async {
    try {
      print('🆕 Setting up first-time Google user');

      final generatedPassword = _generatePasswordFromGoogleData(user);
      await EncryptionService.initializeUserEncryption(
        generatedPassword,
        user.uid,
      );

      final userData = {
        'name': user.displayName ?? googleUser.displayName ?? '',
        'email': user.email ?? '',
        'phone': '',
        'address': '',
      };

      final encryptedData = await EncryptionService.encryptUserData(
        userData,
        user.uid,
      );

      await _database.child('users/${user.uid}').set({
        'encrypted_profile': encryptedData,
        'public_info': {
          'userType': 'customer',
          'isActive': true,
          'joinDate': ServerValue.timestamp,
          'provider': 'google',
          'hasCompletedProfile': false,
          'photoUrl': user.photoURL ?? googleUser.photoUrl ?? '',
        },
        'access_requests': {},
      });

      print('✅ First-time Google user setup completed');
    } catch (e) {
      print('❌ Error setting up first-time Google user: $e');
      throw e;
    }
  }

  static Future<void> _handleExistingGoogleUser(User user) async {
    try {
      print('🔄 Handling existing Google user');

      final hasEncryption = await EncryptionService.hasEncryptionSetup(
        user.uid,
      );

      if (!hasEncryption) {
        final generatedPassword = _generatePasswordFromGoogleData(user);
        await EncryptionService.initializeUserEncryption(
          generatedPassword,
          user.uid,
        );
        print('✅ Restored encryption for existing Google user');
      } else {
        await EncryptionService.getMasterKey(user.uid);
        print('✅ Restored encryption session for existing Google user');
      }
    } catch (e) {
      print('❌ Error handling existing Google user: $e');
      throw e;
    }
  }

  static String _generatePasswordFromGoogleData(User user) {
    final data = '${user.email}_${user.uid}_quickfix_google_2025';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await _googleSignIn.signOut();
      await _auth.signOut();
      print('✅ Google Sign-Out completed');
    } catch (e) {
      print('❌ Error during Google Sign-Out: $e');
      throw e;
    }
  }

  static Future<GoogleSignInAccount?> getCurrentUser() async {
    try {
      await _ensureInitialized();

      // For v7.1.1, we need to listen to events to get current user
      GoogleSignInAccount? currentUser;

      final completer = Completer<GoogleSignInAccount?>();
      late StreamSubscription subscription;

      subscription = _googleSignIn.authenticationEvents.listen((event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            currentUser = event.user;
            completer.complete(currentUser);
            subscription.cancel();
            break;
          case GoogleSignInAuthenticationEventSignOut():
            completer.complete(null);
            subscription.cancel();
            break;
        }
      });

      // Add timeout
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          subscription.cancel();
          return null;
        },
      );
    } catch (e) {
      print('❌ Error getting current Google user: $e');
      return null;
    }
  }
}
