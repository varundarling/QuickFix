import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quickfix/core/notifications/notification_channel.dart';
import 'package:quickfix/core/notifications/notification_permission_manager.dart'; // ✅ ADDED
import 'package:quickfix/core/services/location_service.dart'; // ✅ ADDED
import 'package:quickfix/core/services/notification_service.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/quick_fix.dart';
import 'package:quickfix/core/services/ad_service.dart';
import 'package:quickfix/core/services/firebase_service.dart';

// Background message handler - must be top level
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  //debugPrint('📱 Background message received: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Core Firebase
  await FirebaseService.instance.initialize();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Ads and Notification stack init
  await AdService.instance.initialize();
  await NotificationChannels.createChannels(); // ensure channels exist before any local notif [high/urgent]
  await NotificationService.instance.initialize();

  // Request permissions at app open (notifications + location) and get FCM token
  await _preflightPermissions(); // ✅ NEW

  // Listen for token refresh events
  FCMTokenManager.initializeTokenListener();

  // One-time provider setup (existing)
  try {
    final serviceProvider = ServiceProvider();
    await serviceProvider.addAvailabilityToExistingServices();
  } catch (e) {
    //debugPrint('❌ Error in one-time setup: $e');
  }

  //debugPrint('🌟 Initializing rating system...');

  //print('Connected to Firebase app → ${Firebase.app().name}');
  runApp(const QuickFix());
}

// Requests notification + location permissions up front and pre-fetches FCM token
Future<void> _preflightPermissions() async {
  try {
    // Notifications
    await NotificationPermissionManager.requestNotificationPermission();
  } catch (e) {
    //debugPrint('⚠️ Notification permission request failed (non-fatal): $e');
  }

  try {
    // Get FCM token early; user-specific save to Firestore will still occur post-login via AuthProvider
    await FCMTokenManager.getToken();
  } catch (e) {
    //debugPrint('⚠️ FCM token prefetch failed (non-fatal): $e');
  }

  try {
    // Location
    final granted = await LocationService.instance.requestPermission();
    if (!granted) {
      //debugPrint('❌ Location permission denied at startup');
    }

    // Try to enable device location services if off
    final isEnabled = await LocationService.instance.isLocationEnabled();
    if (!isEnabled) {
      await LocationService.instance.enableLocationService();
    }
  } catch (e) {
    //debugPrint('⚠️ Location preflight failed (non-fatal): $e');
  }
}

// FCM Token Manager (keep your existing code)
class FCMTokenManager {
  static String? _cachedToken;

  static Future<bool> requestNotificationPermission() async {
    try {
      PermissionStatus status = await Permission.notification.status;

      if (status.isGranted) {
        //debugPrint('✅ Notification permission already granted');
        return true;
      }

      if (status.isDenied) {
        //('🔔 Requesting notification permission...');
        status = await Permission.notification.request();
        return status.isGranted;
      }

      return false;
    } catch (e) {
      //debugPrint('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  static Future<String?> getToken() async {
    try {
      bool permissionGranted = await requestNotificationPermission();
      if (!permissionGranted) {
        //debugPrint('❌ Cannot get FCM token: Permission denied');
        return null;
      }

      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        //debugPrint('❌ FCM permission denied');
        return null;
      }

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          String? token = await FirebaseMessaging.instance.getToken();
          if (token != null && token.isNotEmpty) {
            _cachedToken = token;
            //debugPrint('✅ FCM Token obtained: ${token.substring(0, 20)}...');
            return token;
          }
        } catch (e) {
          //debugPrint('❌ Token attempt $attempt failed: $e');
        }

        if (attempt < 3) {
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }

      return null;
    } catch (e) {
      //debugPrint('❌ Error in getToken: $e');
      return null;
    }
  }

  static void initializeTokenListener() {
    FirebaseMessaging.instance.onTokenRefresh
        .listen((fcmToken) {
          _cachedToken = fcmToken;
          //debugPrint('✅ Token refreshed: ${fcmToken.substring(0, 20)}...');
        })
        .onError((err) {
          //debugPrint('❌ Error in token refresh: $err');
        });
  }
}
