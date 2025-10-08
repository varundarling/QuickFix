import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  // ANDROID-ONLY: Simple secure storage configuration for local caching
  static const FlutterSecureStorage secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Session storage for quick access
  static final Map<String, String> sessionKeys = {};

  // Generate master key from password
  static Future<String> deriveMasterKey(String password, String userUID) async {
    final salt = utf8.encode('${userUID}quickfixsalt2025');
    final passwordBytes = utf8.encode(password);
    var hmacSha256 = Hmac(sha256, salt);
    var digest = hmacSha256.convert(passwordBytes);

    // PBKDF2-like key stretching
    for (int i = 0; i < 10000; i++) {
      hmacSha256 = Hmac(sha256, salt);
      digest = hmacSha256.convert(digest.bytes);
    }

    return base64.encode(digest.bytes);
  }

  // Generate device convenience key
  static Future<String> generateDeviceKey() async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(bytes);
  }

  // Generate or get device salt for encryption
  static Future<String> _getOrCreateDeviceSalt(String userUID) async {
    try {
      // Try to get existing salt from Firebase first
      final snapshot = await FirebaseDatabase.instance
          .ref('users/$userUID/security/device_salt')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        return snapshot.value.toString();
      }

      // Generate new salt if doesn't exist
      final random = Random.secure();
      final bytes = List<int>.generate(32, (i) => random.nextInt(256));
      final newSalt = base64.encode(bytes);

      // Store in Firebase for future use
      await FirebaseDatabase.instance
          .ref('users/$userUID/security/device_salt')
          .set(newSalt);

      return newSalt;
    } catch (e) {
      debugPrint('❌ [ENCRYPTION] Error with device salt: $e');
      // Fallback to user-specific salt
      final fallbackSalt = utf8.encode('${userUID}_fallback_salt_2025');
      return base64.encode(fallbackSalt);
    }
  }

  // Initialize encryption for user - NOW STORES IN FIREBASE
  static Future<void> initializeUserEncryption(
    String password,
    String userUID,
  ) async {
    try {
      debugPrint('🔐 [ENCRYPTION] Initializing encryption for: $userUID');

      // Generate master key from password (deterministic)
      final masterKey = await deriveMasterKey(password, userUID);

      // Get or create device salt for this user
      final deviceSalt = await _getOrCreateDeviceSalt(userUID);

      // Encrypt master key with device salt
      final encryptedMasterKey = simpleEncrypt(masterKey, deviceSalt);

      // Store encrypted master key in Firebase Database
      await FirebaseDatabase.instance
          .ref('users/$userUID/security/encrypted_master_key')
          .set(encryptedMasterKey);

      // Also cache locally for faster access
      await secureStorage.write(
        key: 'cached_masterkey_$userUID',
        value: encryptedMasterKey,
      );
      await secureStorage.write(key: 'cached_salt_$userUID', value: deviceSalt);

      // Store master key in memory for current session
      sessionKeys[userUID] = masterKey;

      // Store sync timestamp
      await FirebaseDatabase.instance
          .ref('users/$userUID/security/last_key_sync')
          .set(ServerValue.timestamp);

      debugPrint(
        '✅ [ENCRYPTION] Encryption initialized and stored in Firebase',
      );
    } catch (e) {
      debugPrint('❌ [ENCRYPTION] Failed to initialize encryption: $e');
      rethrow;
    }
  }

  // Get master key with Firebase fallback
  static Future<String?> getMasterKey(
    String userUID, [
    String? password,
  ]) async {
    try {
      // Check session first (fastest)
      if (sessionKeys.containsKey(userUID)) {
        debugPrint('✅ [ENCRYPTION] Using cached session key');
        return sessionKeys[userUID];
      }

      // Try local cache first
      try {
        final cachedEncryptedKey = await secureStorage.read(
          key: 'cached_masterkey_$userUID',
        );
        final cachedSalt = await secureStorage.read(
          key: 'cached_salt_$userUID',
        );

        if (cachedEncryptedKey != null && cachedSalt != null) {
          final masterKey = simpleDecrypt(cachedEncryptedKey, cachedSalt);
          if (isValidKey(masterKey)) {
            sessionKeys[userUID] = masterKey;
            debugPrint('✅ [ENCRYPTION] Restored from local cache');
            return masterKey;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [ENCRYPTION] Local cache read failed: $e');
      }

      // Try Firebase Database
      try {
        final encryptedKeySnapshot = await FirebaseDatabase.instance
            .ref('users/$userUID/security/encrypted_master_key')
            .get();

        final deviceSaltSnapshot = await FirebaseDatabase.instance
            .ref('users/$userUID/security/device_salt')
            .get();

        if (encryptedKeySnapshot.exists && deviceSaltSnapshot.exists) {
          final encryptedMasterKey = encryptedKeySnapshot.value.toString();
          final deviceSalt = deviceSaltSnapshot.value.toString();

          final masterKey = simpleDecrypt(encryptedMasterKey, deviceSalt);

          if (isValidKey(masterKey)) {
            sessionKeys[userUID] = masterKey;

            // Cache locally for faster access next time
            await secureStorage.write(
              key: 'cached_masterkey_$userUID',
              value: encryptedMasterKey,
            );
            await secureStorage.write(
              key: 'cached_salt_$userUID',
              value: deviceSalt,
            );

            debugPrint('✅ [ENCRYPTION] Restored from Firebase Database');
            return masterKey;
          } else {
            debugPrint('⚠️ [ENCRYPTION] Invalid stored key, clearing...');
            await clearStoredKeys(userUID);
          }
        }
      } catch (e) {
        debugPrint('⚠️ [ENCRYPTION] Firebase read failed: $e');
      }

      // Fallback to password derivation
      if (password != null) {
        final masterKey = await deriveMasterKey(password, userUID);
        sessionKeys[userUID] = masterKey;

        // Store the key in Firebase for future cross-device use
        try {
          await _storeKeyInFirebase(userUID, masterKey);
        } catch (e) {
          debugPrint('⚠️ [ENCRYPTION] Failed to store key in Firebase: $e');
        }

        debugPrint(
          '✅ [ENCRYPTION] Derived from password and stored in Firebase',
        );
        return masterKey;
      }

      debugPrint('❌ [ENCRYPTION] No key source available');
      return null;
    } catch (e) {
      debugPrint('❌ [ENCRYPTION] Error getting master key: $e');
      return null;
    }
  }

  // Store key in Firebase Database
  static Future<void> _storeKeyInFirebase(
    String userUID,
    String masterKey,
  ) async {
    try {
      final deviceSalt = await _getOrCreateDeviceSalt(userUID);
      final encryptedMasterKey = simpleEncrypt(masterKey, deviceSalt);

      await FirebaseDatabase.instance
          .ref('users/$userUID/security/encrypted_master_key')
          .set(encryptedMasterKey);

      await FirebaseDatabase.instance
          .ref('users/$userUID/security/last_key_sync')
          .set(ServerValue.timestamp);

      // Also cache locally
      await secureStorage.write(
        key: 'cached_masterkey_$userUID',
        value: encryptedMasterKey,
      );
      await secureStorage.write(key: 'cached_salt_$userUID', value: deviceSalt);

      debugPrint('✅ [ENCRYPTION] Key stored in Firebase Database');
    } catch (e) {
      debugPrint('❌ [ENCRYPTION] Failed to store key in Firebase: $e');
      rethrow;
    }
  }

  // Encrypt user data
  static Future<String> encryptUserData(
    Map<String, dynamic> data,
    String userUID,
  ) async {
    final masterKey = sessionKeys[userUID];
    if (masterKey == null) {
      throw Exception('No encryption key available. Please re-authenticate.');
    }

    try {
      final jsonData = jsonEncode(data);
      final encrypted = simpleEncrypt(jsonData, masterKey);
      debugPrint('✅ [ENCRYPTION] Data encrypted successfully');
      return encrypted;
    } catch (e) {
      debugPrint('❌ [ENCRYPTION] Encryption failed: $e');
      throw Exception('Failed to encrypt data');
    }
  }

  // Decrypt user data
  static Future<Map<String, dynamic>?> decryptUserData(
    String encryptedData,
    String userUID,
  ) async {
    try {
      final masterKey = sessionKeys[userUID];
      if (masterKey == null) {
        debugPrint('❌ [ENCRYPTION] No session key available for decryption');
        throw Exception('No decryption key available');
      }

      final decryptedJson = simpleDecrypt(encryptedData, masterKey);
      final result = jsonDecode(decryptedJson) as Map<String, dynamic>;
      debugPrint('✅ [ENCRYPTION] Data decrypted successfully');
      return result;
    } catch (e) {
      debugPrint('❌ [ENCRYPTION] Decryption failed: $e');
      throw Exception('Failed to decrypt data: ${e.toString()}');
    }
  }

  // Simple XOR encryption
  static String simpleEncrypt(String data, String key) {
    final dataBytes = utf8.encode(data);
    final keyBytes = base64.decode(key);
    final encrypted = <int>[];

    for (int i = 0; i < dataBytes.length; i++) {
      encrypted.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return base64.encode(encrypted);
  }

  static String simpleDecrypt(String encryptedData, String key) {
    final encryptedBytes = base64.decode(encryptedData);
    final keyBytes = base64.decode(key);
    final decrypted = <int>[];

    for (int i = 0; i < encryptedBytes.length; i++) {
      decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return utf8.decode(decrypted);
  }

  // Session management
  static void clearSession(String userUID) {
    sessionKeys.remove(userUID);
    debugPrint('🗑️ [ENCRYPTION] Session cleared');
  }

  static bool hasEncryptionSetup(String userUID) {
    // Quick check - if we have a session key, encryption is set up
    if (sessionKeys.containsKey(userUID)) return true;

    // Otherwise would need async check, but for simplicity return false
    return false;
  }

  // Restore encryption session from Firebase with local cache fallback
  static Future<bool> restoreEncryptionSession(String userUID) async {
    try {
      if (sessionKeys.containsKey(userUID)) {
        debugPrint('✅ [ENCRYPTION] Session already exists');
        return true;
      }

      // Try local cache first
      try {
        final cachedEncryptedKey = await secureStorage.read(
          key: 'cached_masterkey_$userUID',
        );
        final cachedSalt = await secureStorage.read(
          key: 'cached_salt_$userUID',
        );

        if (cachedEncryptedKey != null && cachedSalt != null) {
          final masterKey = simpleDecrypt(cachedEncryptedKey, cachedSalt);
          if (isValidKey(masterKey)) {
            sessionKeys[userUID] = masterKey;
            debugPrint('✅ [ENCRYPTION] Session restored from local cache');
            return true;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [ENCRYPTION] Local cache failed, trying Firebase: $e');
      }

      // Try Firebase Database
      final encryptedKeySnapshot = await FirebaseDatabase.instance
          .ref('users/$userUID/security/encrypted_master_key')
          .get();

      final deviceSaltSnapshot = await FirebaseDatabase.instance
          .ref('users/$userUID/security/device_salt')
          .get();

      if (encryptedKeySnapshot.exists && deviceSaltSnapshot.exists) {
        try {
          final encryptedMasterKey = encryptedKeySnapshot.value.toString();
          final deviceSalt = deviceSaltSnapshot.value.toString();

          final masterKey = simpleDecrypt(encryptedMasterKey, deviceSalt);

          if (isValidKey(masterKey)) {
            sessionKeys[userUID] = masterKey;

            // Update local cache
            await secureStorage.write(
              key: 'cached_masterkey_$userUID',
              value: encryptedMasterKey,
            );
            await secureStorage.write(
              key: 'cached_salt_$userUID',
              value: deviceSalt,
            );

            debugPrint(
              '✅ [ENCRYPTION] Session restored successfully from Firebase',
            );
            return true;
          }
        } catch (e) {
          debugPrint('❌ [ENCRYPTION] Failed to decrypt stored key: $e');
        }
      }

      debugPrint('❌ [ENCRYPTION] No valid stored session found');
      return false;
    } catch (e) {
      debugPrint('❌ [ENCRYPTION] Error restoring session: $e');
      return false;
    }
  }

  // Helper methods
  static bool isValidKey(String key) {
    try {
      final decoded = base64.decode(key);
      return decoded.length >= 16;
    } catch (e) {
      return false;
    }
  }

  // Clear stored keys from both Firebase and local cache
  static Future<void> clearStoredKeys(String userUID) async {
    try {
      // Clear from Firebase Database
      await FirebaseDatabase.instance.ref('users/$userUID/security').remove();

      // Clear from local cache
      await secureStorage.delete(key: 'cached_masterkey_$userUID');
      await secureStorage.delete(key: 'cached_salt_$userUID');

      // Clear session
      sessionKeys.remove(userUID);

      debugPrint('🗑️ [ENCRYPTION] All stored keys cleared');
    } catch (e) {
      debugPrint('❌ [ENCRYPTION] Error clearing stored keys: $e');
    }
  }

  static Future<bool> ensureSessionReady(String userUID) async {
    if (isSessionReady(userUID)) return true;
    return await restoreEncryptionSession(userUID);
  }

  static bool isSessionReady(String userUID) {
    return sessionKeys.containsKey(userUID);
  }

  // Sync encryption key across all user devices
  static Future<void> syncEncryptionKeyAcrossDevices(String userUID) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get the master key from current session
      final masterKey = sessionKeys[userUID];
      if (masterKey == null) return;

      // Store in Firebase with current timestamp
      await _storeKeyInFirebase(userUID, masterKey);

      debugPrint('✅ [ENCRYPTION] Key synced across devices');
    } catch (e) {
      debugPrint('❌ [ENCRYPTION] Failed to sync key across devices: $e');
    }
  }

  // Check if key needs to be synced from another device
  static Future<bool> checkForKeyUpdates(String userUID) async {
    try {
      // Check if there's a key in Firebase and compare with local cache
      final firebaseSnapshot = await FirebaseDatabase.instance
          .ref('users/$userUID/security/encrypted_master_key')
          .get();

      await FirebaseDatabase.instance
          .ref('users/$userUID/security/last_key_sync')
          .get();

      if (firebaseSnapshot.exists && !sessionKeys.containsKey(userUID)) {
        // Key exists in Firebase but not in current session
        await restoreEncryptionSession(userUID);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ [ENCRYPTION] Failed to check for key updates: $e');
      return false;
    }
  }

  // Force refresh key from Firebase (useful when logging in from new device)
  static Future<bool> forceRefreshFromFirebase(String userUID) async {
    try {
      // Clear local cache to force Firebase read
      await secureStorage.delete(key: 'cached_masterkey_$userUID');
      await secureStorage.delete(key: 'cached_salt_$userUID');
      sessionKeys.remove(userUID);

      // Restore from Firebase
      return await restoreEncryptionSession(userUID);
    } catch (e) {
      debugPrint('❌ [ENCRYPTION] Failed to force refresh from Firebase: $e');
      return false;
    }
  }
}
