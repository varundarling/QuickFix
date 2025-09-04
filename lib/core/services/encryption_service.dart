import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(groupId: 'your.app.group.id'),
  );

  // Generate master key from password
  static Future<String> _deriveMasterKey(
    String password,
    String userUID,
  ) async {
    final salt = utf8.encode(userUID + 'quickfix_salt_2025');
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
  static Future<String> _generateDeviceKey() async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(bytes);
  }

  // Initialize encryption for user (called during signup/login)
  static Future<void> initializeUserEncryption(
    String password,
    String userUID,
  ) async {
    // Generate master key from password
    final masterKey = await _deriveMasterKey(password, userUID);

    // Generate device convenience key
    final deviceKey = await _generateDeviceKey();

    // Encrypt master key with device key for convenience storage
    final encryptedMasterKey = _simpleEncrypt(masterKey, deviceKey);

    // Store device key and encrypted master key
    await _secureStorage.write(key: 'device_key_$userUID', value: deviceKey);
    await _secureStorage.write(
      key: 'master_key_$userUID',
      value: encryptedMasterKey,
    );

    // Store master key in memory for current session
    _sessionKeys[userUID] = masterKey;
  }

  // Session storage for quick access
  static final Map<String, String> _sessionKeys = {};

  // Get master key (try device convenience first, fallback to password)
  static Future<String?> getMasterKey(
    String userUID, {
    String? password,
  }) async {
    // Check session first
    if (_sessionKeys.containsKey(userUID)) {
      return _sessionKeys[userUID];
    }

    // Try device convenience key
    try {
      final deviceKey = await _secureStorage.read(key: 'device_key_$userUID');
      final encryptedMasterKey = await _secureStorage.read(
        key: 'master_key_$userUID',
      );

      if (deviceKey != null && encryptedMasterKey != null) {
        final masterKey = _simpleDecrypt(encryptedMasterKey, deviceKey);
        _sessionKeys[userUID] = masterKey;
        return masterKey;
      }
    } catch (e) {
      print('Device key failed, need password');
    }

    // Fallback to password derivation
    if (password != null) {
      final masterKey = await _deriveMasterKey(password, userUID);
      _sessionKeys[userUID] = masterKey;
      return masterKey;
    }

    return null;
  }

  // Encrypt user data
  static Future<String> encryptUserData(
    Map<String, dynamic> data,
    String userUID,
  ) async {
    final masterKey = _sessionKeys[userUID];
    if (masterKey == null) {
      throw Exception('No encryption key available. Please re-authenticate.');
    }

    final jsonData = jsonEncode(data);
    return _simpleEncrypt(jsonData, masterKey);
  }

  // Decrypt user data
  static Future<Map<String, dynamic>> decryptUserData(
    String encryptedData,
    String userUID,
  ) async {
    final masterKey = _sessionKeys[userUID];
    if (masterKey == null) {
      throw Exception('No decryption key available. Please re-authenticate.');
    }

    final decryptedJson = _simpleDecrypt(encryptedData, masterKey);
    return jsonDecode(decryptedJson);
  }

  // Simple XOR encryption (you can replace with AES for production)
  static String _simpleEncrypt(String data, String key) {
    final dataBytes = utf8.encode(data);
    final keyBytes = base64.decode(key);
    final encrypted = <int>[];

    for (int i = 0; i < dataBytes.length; i++) {
      encrypted.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return base64.encode(encrypted);
  }

  static String _simpleDecrypt(String encryptedData, String key) {
    final encryptedBytes = base64.decode(encryptedData);
    final keyBytes = base64.decode(key);
    final decrypted = <int>[];

    for (int i = 0; i < encryptedBytes.length; i++) {
      decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return utf8.decode(decrypted);
  }

  // Clear session (logout)
  static void clearSession(String userUID) {
    _sessionKeys.remove(userUID);
  }

  // Check if user has encryption setup
  static Future<bool> hasEncryptionSetup(String userUID) async {
    final deviceKey = await _secureStorage.read(key: 'device_key_$userUID');
    return deviceKey != null;
  }
}
