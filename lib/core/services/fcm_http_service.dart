import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class FCMHttpService {
  static FCMHttpService? _instance;
  static FCMHttpService get instance => _instance ??= FCMHttpService._();

  FCMHttpService._();

  String? _projectId;
  String? _accessToken;
  DateTime? _tokenExpiry;

  Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
      _projectId = dotenv.env['FIREBASE_PROJECT_ID'];

      if (_projectId == null || _projectId!.isEmpty) {
        throw Exception('FIREBASE_PROJECT_ID not found or empty in .env file');
      }

      // Test token generation immediately
      await _getAccessToken();
      debugPrint(
        '✅ FCMHttpService initialized successfully for project: $_projectId',
      );
    } catch (e) {
      debugPrint('❌ FCMHttpService initialization failed: $e');
      rethrow;
    }
  }

  /// Get OAuth 2.0 access token using service account
  Future<String> _getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(Duration(minutes: 5)))) {
      return _accessToken!;
    }

    try {
      String serviceAccountJson;

      try {
        serviceAccountJson = await rootBundle.loadString(
          'assets/service-account.json',
        );
      } catch (e) {
        debugPrint('❌ Failed to load service account from assets: $e');
        throw Exception('Service account file not found in assets');
      }

      final serviceAccountData = jsonDecode(serviceAccountJson);

      if (serviceAccountData['private_key'] == null ||
          serviceAccountData['client_email'] == null) {
        throw Exception('Invalid service account JSON structure');
      }

      final accountCredentials = ServiceAccountCredentials.fromJson(
        serviceAccountData,
      );
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      final authClient = await clientViaServiceAccount(
        accountCredentials,
        scopes,
      );

      _accessToken = authClient.credentials.accessToken.data;
      _tokenExpiry = authClient.credentials.accessToken.expiry;

      debugPrint('✅ New access token generated, expires: $_tokenExpiry');
      return _accessToken!;
    } catch (e) {
      debugPrint('❌ Error getting access token: $e');
      rethrow;
    }
  }

  /// Send notification via FCM HTTP v1 API
  Future<bool> sendNotification({
    String? fcmToken,
    String? topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_projectId == null) {
      debugPrint('❌ Project ID not initialized');
      return false;
    }

    try {
      final accessToken = await _getAccessToken();
      final url =
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

      final Map<String, dynamic> message = {
        'message': {
          'notification': {'title': title, 'body': body},
          'data':
              data?.map((key, value) => MapEntry(key, value.toString())) ?? {},
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'high_importance_channel',
              'sound': 'default',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
          'apns': {
            'payload': {
              'aps': {'sound': 'default', 'badge': 1},
            },
          },
        },
      };

      if (fcmToken != null) {
        message['message']['token'] = fcmToken;
      } else if (topic != null) {
        message['message']['topic'] = topic;
      } else {
        debugPrint('❌ No target specified for FCM message');
        return false;
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ FCM HTTP v1 message sent: ${responseData['name']}');
        return true;
      } else {
        debugPrint(
          '❌ FCM HTTP v1 error: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending FCM HTTP v1 message: $e');
      return false;
    }
  }

  /// ✅ MOVED: Send high priority notification for real-time delivery
  Future<bool> sendHighPriorityNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_projectId == null) {
      debugPrint('❌ Project ID not initialized');
      return false;
    }

    try {
      final accessToken = await _getAccessToken();
      final url =
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

      final message = {
        'message': {
          'token': fcmToken,
          'notification': {'title': title, 'body': body},
          'data': data?.map((k, v) => MapEntry(k, v.toString())) ?? {},
          'android': {
            'priority': 'high',
            'ttl': '600s',
            'notification': {
              'channel_id': 'urgent_notifications',
              'priority': 'high',
              'sound': 'default',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
          'apns': {
            'headers': {'apns-priority': '10'},
            'payload': {
              'aps': {'sound': 'default', 'badge': 1},
            },
          },
        },
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ High priority FCM message sent');
        return true;
      } else {
        debugPrint('❌ FCM error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending high priority notification: $e');
      return false;
    }
  }

  /// ✅ MOVED: Send notifications to multiple tokens (batch)
  Future<int> sendBatchNotifications({
    required List<String> fcmTokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    int successCount = 0;

    for (String token in fcmTokens) {
      bool success = await sendHighPriorityNotification(
        fcmToken: token,
        title: title,
        body: body,
        data: data,
      );

      if (success) successCount++;

      // Small delay to avoid rate limiting
      await Future.delayed(Duration(milliseconds: 100));
    }

    debugPrint('✅ Sent $successCount/${fcmTokens.length} notifications');
    return successCount;
  }

  // ✅ ADDED: Helper methods for token management
  Future<String?> getFCMToken() async {
    try {
      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission');

        if (Platform.isIOS) {
          String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken == null) {
            debugPrint('APNS token not available yet');
            return null;
          }
        }

        String? token = await FirebaseMessaging.instance.getToken();
        debugPrint('FCM Token: $token');
        return token;
      } else {
        debugPrint('Permission denied');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  Future<String?> getTokenWithConnectivityCheck() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      debugPrint('No internet connection');
      return null;
    }

    try {
      String? token = await FirebaseMessaging.instance.getToken();
      return token;
    } catch (e) {
      debugPrint('Network error getting token: $e');
      return null;
    }
  }
}

// ✅ SIMPLIFIED: FCMTokenManager - only for token management
class FCMTokenManager {
  static String? _cachedToken;

  static Future<String?> getToken() async {
    try {
      if (_cachedToken != null) {
        return _cachedToken;
      }

      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('❌ Notification permission denied');
        return null;
      }

      if (Platform.isIOS) {
        String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('❌ APNS token not available');
          return null;
        }
        debugPrint('✅ APNS token available');
      }

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          String? token = await FirebaseMessaging.instance.getToken();
          if (token != null && token.isNotEmpty) {
            _cachedToken = token;
            debugPrint('✅ FCM Token obtained: ${token.substring(0, 20)}...');
            return token;
          }
        } catch (e) {
          debugPrint('❌ Token attempt $attempt failed: $e');
        }

        if (attempt < 3) {
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }

      debugPrint('❌ Failed to get FCM token after 3 attempts');
      return null;
    } catch (e) {
      debugPrint('❌ Error in getToken: $e');
      return null;
    }
  }

  static void initializeTokenListener() {
    FirebaseMessaging.instance.onTokenRefresh
        .listen((fcmToken) {
          _cachedToken = fcmToken;
          debugPrint('✅ Token refreshed: ${fcmToken.substring(0, 20)}...');
        })
        .onError((err) {
          debugPrint('❌ Error in token refresh: $err');
        });
  }
}
